"""Carga idempotente no MySQL 8."""

from __future__ import annotations

import argparse
import json
import os
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

try:
    import mysql.connector
except ImportError:  # permite rodar transformações/testes sem dependência instalada
    mysql = None  # type: ignore


ETL_EXECUTION_SQL = """
INSERT INTO etl_execucoes
  (id_execucao, iniciado_em, finalizado_em, status, filtros_json,
   paginas, registros_extraidos, registros_transformados, proposicoes_processadas,
   autores_processados, tramitacoes_processadas, mensagem_erro,
   coleta_parcial, avisos_json)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""


class MySQLLoader:
    def __init__(self, connection_config: dict[str, Any]) -> None:
        if "mysql" not in globals() or mysql is None:
            raise RuntimeError("Instale mysql-connector-python para executar a carga")
        self.connection_config = connection_config

    @contextmanager
    def connection(self) -> Iterator[Any]:
        conn = mysql.connector.connect(**self.connection_config)
        try:
            yield conn
        finally:
            conn.close()

    def start_execution(self, filters: Any = None) -> tuple[str, datetime]:
        execution_id = str(uuid.uuid4())
        started = datetime.now(timezone.utc)
        with self.connection() as conn:
            cursor = conn.cursor()
            try:
                self._record_execution(
                    cursor,
                    execution_id,
                    started,
                    None,
                    "EM_EXECUCAO",
                    filters,
                    0,
                    0,
                    {"proposicoes": 0, "autores": 0, "tramitacoes": 0},
                    None,
                    False,
                    [],
                )
                conn.commit()
            finally:
                cursor.close()
        return execution_id, started

    def finish_execution(
        self,
        execution_id: str,
        status: str,
        error: str | None = None,
        counts: dict[str, int] | None = None,
        pages: int = 0,
        extracted: int = 0,
        transformed: int = 0,
        partial: bool = False,
        warnings: list[str] | None = None,
    ) -> None:
        counts = counts or {"proposicoes": 0, "autores": 0, "tramitacoes": 0}
        with self.connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    """
                    UPDATE etl_execucoes
                    SET finalizado_em=%s, status=%s, paginas=%s,
                        registros_extraidos=%s, registros_transformados=%s,
                        proposicoes_processadas=%s, autores_processados=%s,
                        tramitacoes_processadas=%s, mensagem_erro=%s,
                        coleta_parcial=%s, avisos_json=%s
                    WHERE id_execucao=%s
                    """,
                    (
                        datetime.now(timezone.utc),
                        status,
                        pages,
                        extracted,
                        transformed,
                        counts["proposicoes"],
                        counts["autores"],
                        counts["tramitacoes"],
                        error,
                        partial,
                        json.dumps(warnings or [], ensure_ascii=False),
                        execution_id,
                    ),
                )
                conn.commit()
            finally:
                cursor.close()

    def load(
        self,
        payload: dict[str, Any],
        filters: Any = None,
        extracted_count: int | None = None,
        transformed_count: int | None = None,
        execution_id: str | None = None,
        started: datetime | None = None,
        pages: int = 0,
        partial: bool = False,
        warnings: list[str] | None = None,
    ) -> dict[str, Any]:
        provided_execution_id = execution_id is not None
        execution_id = execution_id or str(uuid.uuid4())
        started = started or datetime.now(timezone.utc)
        total_transformed = (
            len(payload.get("registros", []))
            if transformed_count is None
            else transformed_count
        )
        counts = {"proposicoes": 0, "autores": 0, "tramitacoes": 0}
        with self.connection() as conn:
            cursor = conn.cursor()
            try:
                for record in payload.get("registros", []):
                    is_new_project = self._upsert_project(cursor, record)
                    if is_new_project:
                        self._notify_new_project(cursor, record)
                    counts["proposicoes"] += 1
                    for author in record.get("autores", []):
                        self._upsert_author(cursor, author)
                        self._upsert_project_author(cursor, record, author)
                        counts["autores"] += 1
                    for tram in record.get("tramitacoes", []):
                        tramitacao_id, is_new_tramitation = self._upsert_tramitacao(cursor, record, tram)
                        if is_new_tramitation and tramitacao_id:
                            self._notify_new_tramitation(cursor, record, tram, tramitacao_id)
                        counts["tramitacoes"] += 1
                # Commit project/author/tramitation changes and the successful
                # execution record atomically. Do not persist data first and then
                # leave etl_execucoes stuck in EM_EXECUCAO if its update fails.
                if provided_execution_id:
                    self._update_execution(
                        cursor,
                        execution_id,
                        "PARCIAL" if partial else "SUCESSO",
                        counts,
                        None,
                        pages=pages,
                        extracted=extracted_count or 0,
                        transformed=total_transformed,
                        partial=partial,
                        warnings=warnings,
                    )
                else:
                    self._record_execution(
                        cursor,
                        execution_id,
                        started,
                        datetime.now(timezone.utc),
                        "PARCIAL" if partial else "SUCESSO",
                        filters,
                        extracted_count or 0,
                        total_transformed,
                        counts,
                        None,
                        partial,
                        warnings,
                        pages,
                    )
                conn.commit()
            except Exception as exc:
                conn.rollback()
                try:
                    if provided_execution_id:
                        self._update_execution(
                            cursor,
                            execution_id,
                            "ERRO",
                            counts,
                            str(exc),
                            pages=pages,
                            extracted=extracted_count or 0,
                            transformed=total_transformed,
                            partial=partial,
                            warnings=warnings,
                        )
                    else:
                        self._record_execution(
                            cursor,
                            execution_id,
                            started,
                            datetime.now(timezone.utc),
                            "ERRO",
                            filters,
                            extracted_count or 0,
                            total_transformed,
                            counts,
                            str(exc),
                            partial,
                            warnings,
                            pages,
                        )
                    conn.commit()
                except Exception as status_exc:
                    conn.rollback()
                    # If even the error log cannot be persisted, retain the
                    # original load failure rather than replacing it with a
                    # secondary logging failure.
                    if hasattr(exc, "add_note"):
                        exc.add_note(f"Também falhou o registro do erro no MySQL: {status_exc}")
                raise
            finally:
                cursor.close()
        return {"id_execucao": execution_id, **counts}

    @staticmethod
    def _upsert_project(cursor: Any, r: dict[str, Any]) -> bool:
        # O registro transformado também contém listas/dicionários de autores,
        # tramitações e última tramitação; eles pertencem a tabelas próprias.
        project_data = {
            key: value
            for key, value in r.items()
            if key not in ("autores", "tramitacoes", "ultima_tramitacao")
        }
        cursor.execute(
            """
            SELECT id_projeto FROM projeto_lei
            WHERE id_projeto=%s OR uri_api=%s
               OR (sigla_tipo=%s AND numero=%s AND ano=%s)
            FOR UPDATE
            """,
            (
                r["id_projeto"], r.get("uri_api"), r["sigla_tipo"],
                r["numero"], r["ano"],
            ),
        )
        existing_rows = cursor.fetchall()
        is_new = not any(int(row[0]) == int(r["id_projeto"]) for row in existing_rows)
        conflicting_ids = {
            int(row[0]) for row in existing_rows
            if int(row[0]) != int(r["id_projeto"])
        }
        if conflicting_ids:
            raise ValueError(
                "Conflito de identidade/URI de proposição: os campos únicos já "
                f"pertencem a outro id_projeto ({sorted(conflicting_ids)})"
            )
        cursor.execute(
            """
        INSERT INTO projeto_lei
          (id_projeto, sigla_tipo, numero, ano, ementa, data_apresentacao, uri_api,
           url_inteiro_teor, codigo_situacao_api, descricao_situacao_api, status_interno,
           lei_numero, lei_tipo, lei_data_publicacao, lei_inicio_vigencia,
           situacao_juridica, lei_fonte_publicacao, vigencia_verificada,
           fonte_vigencia, vigencia_evidencia, vigencia_verificada_em, registro_hash)
        VALUES (%(id_projeto)s, %(sigla_tipo)s, %(numero)s, %(ano)s, %(ementa)s, %(data_apresentacao)s,
                %(uri_api)s, %(url_inteiro_teor)s, %(codigo_situacao_api)s, %(descricao_situacao_api)s,
                %(status_interno)s, %(lei_numero)s, %(lei_tipo)s, %(lei_data_publicacao)s,
                %(lei_inicio_vigencia)s, %(situacao_juridica)s, %(lei_fonte_publicacao)s,
                %(vigencia_verificada)s, %(fonte_vigencia)s, %(vigencia_evidencia)s,
                %(vigencia_verificada_em)s, %(registro_hash)s)
        ON DUPLICATE KEY UPDATE
          sigla_tipo=VALUES(sigla_tipo), numero=VALUES(numero), ano=VALUES(ano),
          ementa=VALUES(ementa), data_apresentacao=VALUES(data_apresentacao), uri_api=VALUES(uri_api),
          url_inteiro_teor=VALUES(url_inteiro_teor), codigo_situacao_api=VALUES(codigo_situacao_api),
          descricao_situacao_api=VALUES(descricao_situacao_api),
          lei_inicio_vigencia=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(lei_inicio_vigencia), lei_inicio_vigencia), NULL),
          situacao_juridica=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(situacao_juridica), situacao_juridica), NULL),
          lei_fonte_publicacao=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(lei_fonte_publicacao), lei_fonte_publicacao), NULL),
          vigencia_verificada=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            GREATEST(vigencia_verificada, VALUES(vigencia_verificada)), FALSE),
          fonte_vigencia=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(fonte_vigencia), fonte_vigencia), NULL),
          vigencia_evidencia=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(vigencia_evidencia), vigencia_evidencia), NULL),
          vigencia_verificada_em=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(vigencia_verificada_em), vigencia_verificada_em), NULL),
          lei_tipo=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(lei_tipo), lei_tipo), VALUES(lei_tipo)),
          lei_data_publicacao=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND lei_numero IS NOT NULL
            AND (VALUES(lei_numero) IS NULL OR VALUES(lei_numero) <=> lei_numero),
            COALESCE(VALUES(lei_data_publicacao), lei_data_publicacao), VALUES(lei_data_publicacao)),
          lei_numero=IF(
            VALUES(status_interno)='TRANSFORMADA_EM_NORMA' AND VALUES(lei_numero) IS NULL
            AND lei_numero IS NOT NULL, lei_numero, VALUES(lei_numero)),
          status_interno=VALUES(status_interno),
          registro_hash=VALUES(registro_hash)
        """,
            project_data,
        )
        return is_new

    @staticmethod
    def _notification_users(cursor: Any, sql: str, params: tuple, preference_keys: tuple[str, ...]) -> list[int]:
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        users = []
        for row in rows:
            prefs = row[1] if len(row) > 1 else None
            if isinstance(prefs, (str, bytes, bytearray)):
                try:
                    prefs = json.loads(prefs.decode() if isinstance(prefs, (bytes, bytearray)) else prefs)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    prefs = {}
            prefs = prefs or {}
            # Null means an account predating saved preferences; don't opt it in silently.
            if isinstance(prefs, dict) and any(prefs.get(key) is True for key in preference_keys):
                users.append(int(row[0]))
        return users

    @classmethod
    def _notify_new_project(cls, cursor: Any, record: dict[str, Any]) -> None:
        users = cls._notification_users(
            cursor,
            "SELECT id_usuario, preferencias_json FROM usuario",
            (),
            ("pref_novos_projetos",),
        )
        title = f"Nova proposição: {record.get('sigla_tipo', '')} {record.get('numero', '')}/{record.get('ano', '')}".strip()
        description = record.get("ementa")
        for user_id in users:
            cursor.execute(
                "INSERT IGNORE INTO notificacao (id_usuario,id_projeto,tipo_evento,titulo,descricao,status_envio) VALUES (%s,%s,'NOVA_PROPOSICAO',%s,%s,'IN_APP')",
                (user_id, record["id_projeto"], title[:200], description),
            )

    @classmethod
    def _notify_new_tramitation(cls, cursor: Any, record: dict[str, Any], tram: dict[str, Any], tramitacao_id: int) -> None:
        users = cls._notification_users(
            cursor,
            "SELECT u.id_usuario,u.preferencias_json FROM usuario u JOIN favorito f ON f.id_usuario=u.id_usuario WHERE f.id_projeto=%s",
            (record["id_projeto"],),
            ("pref_atualizacoes",),
        )
        title = f"Atualização: {record.get('sigla_tipo', '')} {record.get('numero', '')}/{record.get('ano', '')}".strip()
        description = tram.get("descricao_tramitacao") or tram.get("descricao_situacao") or tram.get("despacho")
        for user_id in users:
            cursor.execute(
                "INSERT IGNORE INTO notificacao (id_usuario,id_projeto,id_tramitacao,tipo_evento,titulo,descricao,status_envio) VALUES (%s,%s,%s,'NOVA_TRAMITACAO',%s,%s,'IN_APP')",
                (user_id, record["id_projeto"], tramitacao_id, title[:200], description),
            )

    @staticmethod
    def _upsert_author(cursor: Any, a: dict[str, Any]) -> None:
        cursor.execute(
            """
            SELECT id_autor FROM autor
            WHERE id_autor=%s OR (%s IS NOT NULL AND uri_api=%s)
            FOR UPDATE
            """,
            (a["id_autor"], a.get("uri_api"), a.get("uri_api")),
        )
        conflicting_ids = {
            int(row[0]) for row in cursor.fetchall()
            if int(row[0]) != int(a["id_autor"])
        }
        if conflicting_ids:
            raise ValueError(
                "Conflito de identidade/URI de autor: a URI já pertence a outro "
                f"id_autor ({sorted(conflicting_ids)})"
            )
        cursor.execute(
            """
        INSERT INTO autor (id_autor, nome, tipo, uri_api)
        VALUES (%(id_autor)s, %(nome)s, %(tipo)s, %(uri_api)s)
        ON DUPLICATE KEY UPDATE nome=VALUES(nome), tipo=VALUES(tipo), uri_api=VALUES(uri_api)
        """,
            a,
        )

    @staticmethod
    def _upsert_project_author(
        cursor: Any, r: dict[str, Any], a: dict[str, Any]
    ) -> None:
        cursor.execute(
            """
        INSERT INTO projeto_autor (id_projeto, id_autor, ordem_assinatura, proponente)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE ordem_assinatura=VALUES(ordem_assinatura), proponente=VALUES(proponente)
        """,
            (
                r["id_projeto"],
                a["id_autor"],
                a.get("ordem_assinatura"),
                a.get("proponente", False),
            ),
        )

    @staticmethod
    def _upsert_tramitacao(cursor: Any, r: dict[str, Any], t: dict[str, Any]) -> tuple[int | None, bool]:
        cursor.execute(
            "SELECT id_tramitacao FROM tramitacao WHERE id_projeto=%s AND sequencia=%s FOR UPDATE",
            (r["id_projeto"], t["sequencia"]),
        )
        existing = cursor.fetchall()
        cursor.execute(
            """
        INSERT INTO tramitacao
          (id_projeto, sequencia, data_hora, sigla_orgao, uri_orgao, regime,
           codigo_tipo_tramitacao, codigo_situacao, descricao_situacao, descricao_tramitacao,
           despacho, uri_ultimo_relator, url, ambito, apreciacao)
        VALUES (%(id_projeto)s, %(sequencia)s, %(data_hora)s, %(sigla_orgao)s, %(uri_orgao)s, %(regime)s,
                %(codigo_tipo_tramitacao)s, %(codigo_situacao)s, %(descricao_situacao)s,
                %(descricao_tramitacao)s, %(despacho)s, %(uri_ultimo_relator)s, %(url)s, %(ambito)s, %(apreciacao)s)
        ON DUPLICATE KEY UPDATE
          data_hora=VALUES(data_hora), sigla_orgao=VALUES(sigla_orgao),
          uri_orgao=VALUES(uri_orgao), regime=VALUES(regime),
          codigo_tipo_tramitacao=VALUES(codigo_tipo_tramitacao), codigo_situacao=VALUES(codigo_situacao),
          descricao_situacao=VALUES(descricao_situacao), descricao_tramitacao=VALUES(descricao_tramitacao),
          despacho=VALUES(despacho), uri_ultimo_relator=VALUES(uri_ultimo_relator), url=VALUES(url),
          ambito=VALUES(ambito), apreciacao=VALUES(apreciacao)
        """,
            {**t, "id_projeto": r["id_projeto"]},
        )
        return (int(existing[0][0]) if existing else int(cursor.lastrowid or 0) or None, not existing)

    @staticmethod
    def _record_execution(
        cursor: Any,
        execution_id: str,
        started: datetime,
        finished: datetime,
        status: str,
        filters: Any,
        extracted: int,
        transformed: int,
        counts: dict[str, int],
        error: str | None,
        partial: bool = False,
        warnings: list[str] | None = None,
        pages: int = 0,
    ) -> None:
        cursor.execute(
            ETL_EXECUTION_SQL,
            (
                execution_id,
                started,
                finished,
                status,
                json.dumps(filters, ensure_ascii=False),
                pages,
                extracted,
                transformed,
                counts["proposicoes"],
                counts["autores"],
                counts["tramitacoes"],
                error,
                partial,
                json.dumps(warnings or [], ensure_ascii=False),
            ),
        )

    @staticmethod
    def _update_execution(
        cursor: Any,
        execution_id: str,
        status: str,
        counts: dict[str, int],
        error: str | None,
        *,
        pages: int = 0,
        extracted: int = 0,
        transformed: int = 0,
        partial: bool = False,
        warnings: list[str] | None = None,
    ) -> None:
        cursor.execute(
            """
            UPDATE etl_execucoes
            SET finalizado_em=%s, status=%s, paginas=%s,
                registros_extraidos=%s, registros_transformados=%s,
                proposicoes_processadas=%s, autores_processados=%s,
                tramitacoes_processadas=%s, mensagem_erro=%s,
                coleta_parcial=%s, avisos_json=%s
            WHERE id_execucao=%s
            """,
            (
                datetime.now(timezone.utc),
                status,
                pages,
                extracted,
                transformed,
                counts["proposicoes"],
                counts["autores"],
                counts["tramitacoes"],
                error,
                partial,
                json.dumps(warnings or [], ensure_ascii=False),
                execution_id,
            ),
        )


def db_config(config: dict[str, Any]) -> dict[str, Any]:
    result = dict(config["database"])
    for key in ("user", "password", "host", "port", "database"):
        env_key = f"LEGIS_DB_{key.upper()}"
        if os.getenv(env_key):
            result[key] = os.environ[env_key]
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="etl/config.json")
    parser.add_argument("--input", default="etl/data/transformed.json")
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    result = MySQLLoader(db_config(config)).load(payload, config["filters"])
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
