import os
from datetime import datetime

os.environ.update(
    {
        "DATABASE_URL": "sqlite:///./test_legis.db",
        "ENVIRONMENT": "test",
        "ADMIN_TOKEN": "test-token",
        "DEFAULT_USER_ID": "1",
    }
)
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db import Base, get_db
from app.main import app
import app.api.routes as routes

routes.run_sync = lambda: None
from app.models import Autor, Favorito, ProjetoAutor, ProjetoLei, Tramitacao, Usuario

engine = create_engine(
    "sqlite:///./test_legis.db", connect_args={"check_same_thread": False}
)
TestingSession = sessionmaker(bind=engine)


@pytest.fixture(autouse=True)
def db():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    s = TestingSession()
    s.add_all(
        [
            Usuario(
                id_usuario=1,
                nome="Teste",
                email="teste@example.org",
                senha_hash="local",
            ),
            ProjetoLei(
                id_projeto=540979,
                sigla_tipo="PL",
                numero="2913",
                ano=2021,
                ementa="Cria o Selo Verde Cacau Cabruca.",
                uri_api="http://camara/540979",
                status_interno="TRANSFORMADA_EM_NORMA",
                lei_numero="14877/2024",
                lei_tipo="Lei Ordinária",
                vigencia_verificada=False,
                situacao_juridica=None,
            ),
            Autor(id_autor=160666, nome="Félix Mendonça Júnior"),
        ]
    )
    s.add(
        ProjetoAutor(
            id_projeto=540979, id_autor=160666, proponente=True, ordem_assinatura=1
        )
    )
    s.add(
        Tramitacao(
            id_tramitacao=1,
            id_projeto=540979,
            sequencia=1,
            data_hora=datetime(2024, 6, 4),
            sigla_orgao="MESA",
            codigo_situacao=1140,
            descricao_situacao="Transformada em Norma",
            descricao_tramitacao="Transformação em Norma Jurídica",
            despacho="Lei Ordinária 14877/2024",
        )
    )
    s.commit()
    s.close()
    yield
    Base.metadata.drop_all(engine)


def override():
    s = TestingSession()
    try:
        yield s
    finally:
        s.close()


app.dependency_overrides[get_db] = override


@pytest.fixture
def client():
    return TestClient(app)
