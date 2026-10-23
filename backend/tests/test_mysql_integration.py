from __future__ import annotations

import os
import re
import uuid
from copy import deepcopy
from datetime import datetime
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError

from etl.load import MySQLLoader

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = sorted((ROOT / "database" / "migrations").glob("*.sql"))
MYSQL_URL = os.getenv("LEGIS_TEST_MYSQL_URL", "mysql+mysqlconnector://root:root@localhost:3306/legis")
pytestmark = pytest.mark.skipif(not MYSQL_URL, reason="LEGIS_TEST_MYSQL_URL não configurado")


def _statements(script: str):
    no_line_comments = re.sub(r"(?m)^\s*--.*$", "", script)
    return [part.strip() for part in no_line_comments.split(";") if part.strip()]


def test_migrations_and_idempotent_etl_persistence_on_mysql8():
    base_url = make_url(MYSQL_URL)
    if base_url.get_backend_name() != "mysql":
        pytest.fail("LEGIS_TEST_MYSQL_URL deve usar o dialeto mysql")
    database = f"legis_it_{uuid.uuid4().hex[:10]}"
    admin_engine = create_engine(base_url.set(database="mysql"), pool_pre_ping=True)
    schema_engine = None
    try:
        with admin_engine.begin() as connection:
            version = connection.scalar(text("SELECT VERSION()"))
            version_comment = connection.scalar(text("SELECT @@version_comment"))
            if "mariadb" in f"{version} {version_comment}".lower() or not str(version).startswith("8."):
                pytest.fail(f"É necessário MySQL 8 real; servidor detectado: {version} / {version_comment}")
            connection.execute(text(f"CREATE DATABASE `{database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"))

        schema_engine = create_engine(base_url.set(database=database), pool_pre_ping=True)
        for migration_path in MIGRATIONS:
            script = migration_path.read_text(encoding="utf-8")
            script = re.sub(r"(?i)CREATE DATABASE IF NOT EXISTS legis", f"CREATE DATABASE IF NOT EXISTS `{database}`", script)
            script = re.sub(r"(?i)USE\s+legis\s*;", f"USE `{database}`;", script)
            with schema_engine.connect() as connection:
                for statement in _statements(script):
                    connection.exec_driver_sql(statement)

        seed_paths = [
            ROOT / "database" / "seeds" / "001_seed_inicial.sql",
            ROOT / "database" / "seeds" / "002_proposicoes_recentes_2026.sql",
        ]
        for seed_path in seed_paths:
            seed = seed_path.read_text(encoding="utf-8")
            seed = re.sub(r"(?i)USE\s+legis\s*;", f"USE `{database}`;", seed)
            # Let SQLAlchemy own the transaction; nested START/COMMIT statements
            # would commit outside its transaction bookkeeping.
            seed = re.sub(r"(?im)^\s*(?:START\s+TRANSACTION|COMMIT)\s*;\s*$", "", seed)
            # Executing both seeds twice verifies repeatability without duplicates.
            for _ in range(2):
                # Seed DML must be committed explicitly; closing a plain
                # SQLAlchemy 2.x Connection otherwise rolls back the transaction.
                with schema_engine.begin() as connection:
                    for statement in _statements(seed):
                        connection.exec_driver_sql(statement)

        with schema_engine.begin() as connection:
            assert connection.scalar(
                text("SELECT descricao_situacao_api FROM projeto_lei WHERE id_projeto=2256735")
            ) == "Pronta para Pauta"
            connection.execute(
                text("""
                    UPDATE projeto_lei
                    SET vigencia_verificada=TRUE, situacao_juridica='VIGENTE',
                        fonte_vigencia='https://www2.camara.leg.br/norma',
                        vigencia_evidencia='Trecho oficial de teste suficientemente longo',
                        vigencia_verificada_em=NOW()
                    WHERE id_projeto=540979
                """)
            )

        # Re-running the initial seed must not erase manually reviewed evidence.
        initial_seed = seed_paths[0].read_text(encoding="utf-8")
        initial_seed = re.sub(r"(?i)USE\s+legis\s*;", f"USE `{database}`;", initial_seed)
        initial_seed = re.sub(r"(?im)^\s*(?:START\s+TRANSACTION|COMMIT)\s*;\s*$", "", initial_seed)
        with schema_engine.begin() as connection:
            for statement in _statements(initial_seed):
                connection.exec_driver_sql(statement)
        with schema_engine.connect() as connection:
            verified_seed_row = connection.execute(
                text("SELECT lei_numero, vigencia_verificada, situacao_juridica FROM projeto_lei WHERE id_projeto=540979")
            ).one()
            assert verified_seed_row.lei_numero == "14877/2024"
            assert verified_seed_row.vigencia_verificada in (1, True)
            assert verified_seed_row.situacao_juridica == "VIGENTE"

        record = {
            "id_projeto": 987654321,
            "sigla_tipo": "PL",
            "numero": "99",
            "ano": 2024,
            "ementa": "Teste de integração MySQL",
            "data_apresentacao": None,
            "uri_api": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/987654321",
            "url_inteiro_teor": None,
            "codigo_situacao_api": 1140,
            "descricao_situacao_api": "Transformado em Norma Jurídica",
            "status_interno": "TRANSFORMADA_EM_NORMA",
            "lei_numero": "14999/2024",
            "lei_tipo": "Ordinária",
            "lei_data_publicacao": None,
            "lei_inicio_vigencia": None,
            "situacao_juridica": None,
            "lei_fonte_publicacao": None,
            "vigencia_verificada": False,
            "fonte_vigencia": None,
            "vigencia_evidencia": None,
            "vigencia_verificada_em": None,
            "registro_hash": "b" * 64,
            "autores": [],
            "tramitacoes": [
                {"sequencia": 1, "data_hora": None, "sigla_orgao": None,
                 "uri_orgao": None, "regime": None, "codigo_tipo_tramitacao": None,
                 "codigo_situacao": None, "descricao_situacao": "Movimento inicial",
                 "descricao_tramitacao": None, "despacho": None,
                 "uri_ultimo_relator": None, "url": None, "ambito": None,
                 "apreciacao": None},
            ],
        }
        loader = MySQLLoader(
            {
                "host": base_url.host,
                "port": base_url.port or 3306,
                "user": base_url.username,
                "password": base_url.password,
                "database": database,
            }
        )
        # A UNIQUE collision on identity/URI must fail explicitly instead of
        # letting MySQL's ON DUPLICATE KEY UPDATE mutate the wrong project.
        collision = deepcopy(record)
        collision.update(
            {
                "id_projeto": 888888888,
                "sigla_tipo": "PL",
                "numero": "2913",
                "ano": 2021,
                "uri_api": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/888888888",
            }
        )
        with loader.connection() as connection:
            cursor = connection.cursor()
            try:
                with pytest.raises(ValueError, match="Conflito de identidade/URI"):
                    loader._upsert_project(cursor, collision)
            finally:
                connection.rollback()
                cursor.close()
        with schema_engine.connect() as connection:
            identity_owner = connection.execute(
                text("SELECT id_projeto, uri_api FROM projeto_lei WHERE sigla_tipo='PL' AND numero='2913' AND ano=2021")
            ).one()
            assert identity_owner.id_projeto == 540979
            assert identity_owner.uri_api.endswith("/540979")

        # A transformed norm with an existing manual review must keep that
        # review on refresh when the API still says transformed but the ETL
        # cannot infer the enacted-law number from the current response.
        same_norm_refresh = deepcopy(record)
        same_norm_refresh.update(
            {
                "id_projeto": 540979,
                "sigla_tipo": "PL",
                "numero": "2913",
                "ano": 2021,
                "uri_api": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/540979",
                "codigo_situacao_api": 1140,
                "descricao_situacao_api": "Transformado em Norma Jurídica",
                "status_interno": "TRANSFORMADA_EM_NORMA",
                "lei_numero": None,
                "lei_tipo": None,
                "lei_data_publicacao": None,
                "vigencia_verificada": False,
                "situacao_juridica": None,
                "fonte_vigencia": None,
                "vigencia_evidencia": None,
                "vigencia_verificada_em": None,
                "registro_hash": "e" * 64,
            }
        )
        loader.load({"registros": [same_norm_refresh]}, filters={"test": "preserve-manual-review"})
        with schema_engine.connect() as connection:
            preserved_refresh = connection.execute(
                text("SELECT lei_numero, vigencia_verificada, situacao_juridica FROM projeto_lei WHERE id_projeto=540979")
            ).one()
            assert preserved_refresh.lei_numero == "14877/2024"
            assert preserved_refresh.vigencia_verificada in (1, True)
            assert preserved_refresh.situacao_juridica == "VIGENTE"

        loader.load({"registros": [record]}, filters={"test": True})
        updated = deepcopy(record)
        updated.update(
            {
                "sigla_tipo": "PEC",
                "numero": "100",
                "ano": 2025,
                "ementa": "Registro atualizado pelo upsert",
                "codigo_situacao_api": 900,
                "descricao_situacao_api": "Arquivada",
                "status_interno": "ARQUIVADA",
                "registro_hash": "c" * 64,
            }
        )
        updated["tramitacoes"][0].update(
            {
                "data_hora": datetime(2025, 1, 2, 14, 30),
                "sigla_orgao": "PLEN",
                "descricao_situacao": "Movimento corrigido",
            }
        )
        loader.load({"registros": [updated]}, filters={"test": True})
        loader.load({"registros": [updated]}, filters={"test": True})
        # If the authoritative status moves away from a converted norm, remove
        # its active vigency flag/evidence from the current project row so the
        # API cannot keep presenting a stale verified-law status.
        no_longer_norm = deepcopy(record)
        no_longer_norm.update(
            {
                "id_projeto": 540979,
                "sigla_tipo": "PL",
                "numero": "2913",
                "ano": 2021,
                "uri_api": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/540979",
                "codigo_situacao_api": 910,
                "descricao_situacao_api": "Aguardando Encaminhamento",
                "status_interno": "EM_TRAMITACAO",
                "lei_numero": None,
                "lei_tipo": None,
                "lei_data_publicacao": None,
                "registro_hash": "d" * 64,
            }
        )
        loader.load({"registros": [no_longer_norm]}, filters={"test": "clear-stale-vigency"})

        with schema_engine.connect() as connection:
            assert connection.scalar(text("SELECT COUNT(*) FROM projeto_lei WHERE id_projeto IN (2639107,2639179,2644800)")) == 3
            assert connection.scalar(text("SELECT COUNT(*) FROM projeto_lei WHERE id_projeto IN (540979,2256735)")) == 2
            assert connection.scalar(text("SELECT COUNT(*) FROM projeto_lei WHERE id_projeto=987654321")) == 1
            assert connection.scalar(text("SELECT COUNT(*) FROM tramitacao WHERE id_projeto=987654321 AND sequencia=1")) == 1
            assert connection.scalar(text("SELECT COUNT(*) FROM etl_execucoes")) == 5
            assert connection.scalar(text("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=:db AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='lei_inicio_vigencia'"), {"db": database}) == 1
            updated_row = connection.execute(
                text("""
                    SELECT sigla_tipo, numero, ano, ementa, status_interno, lei_numero
                    FROM projeto_lei WHERE id_projeto=987654321
                """)
            ).one()
            assert tuple(updated_row[:5]) == (
                "PEC", "100", 2025, "Registro atualizado pelo upsert", "ARQUIVADA"
            )
            assert updated_row.lei_numero is None
            updated_tram = connection.execute(
                text("""
                    SELECT data_hora, sigla_orgao, descricao_situacao FROM tramitacao
                    WHERE id_projeto=987654321 AND sequencia=1
                """)
            ).one()
            assert updated_tram.data_hora == datetime(2025, 1, 2, 14, 30)
            assert updated_tram.sigla_orgao == "PLEN"
            assert updated_tram.descricao_situacao == "Movimento corrigido"
            cleared_row = connection.execute(
                text("SELECT status_interno, lei_numero, vigencia_verificada, situacao_juridica, fonte_vigencia, vigencia_evidencia FROM projeto_lei WHERE id_projeto=540979")
            ).one()
            assert cleared_row.status_interno == "EM_TRAMITACAO"
            assert cleared_row.lei_numero is None
            assert cleared_row.vigencia_verificada in (0, False)
            assert cleared_row.situacao_juridica is None
            assert cleared_row.fonte_vigencia is None
            assert cleared_row.vigencia_evidencia is None

        with pytest.raises(IntegrityError):
            with schema_engine.begin() as connection:
                connection.execute(
                    text("INSERT INTO tramitacao (id_projeto, sequencia) VALUES (123456789, 999)")
                )
    finally:
        if schema_engine is not None:
            schema_engine.dispose()
        with admin_engine.begin() as connection:
            connection.execute(text(f"DROP DATABASE IF EXISTS `{database}`"))
        admin_engine.dispose()
