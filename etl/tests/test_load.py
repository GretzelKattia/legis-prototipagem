from __future__ import annotations

import pytest

from etl.load import MySQLLoader


class CursorDouble:
    def __init__(self, rows):
        self.rows = rows
        self.executed = []

    def execute(self, statement, params=None):
        self.executed.append((statement, params))

    def fetchall(self):
        return self.rows

    def close(self):
        pass


def project_record():
    return {
        "id_projeto": 888888888,
        "sigla_tipo": "PL",
        "numero": "2913",
        "ano": 2021,
        "uri_api": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/888888888",
    }


def test_project_upsert_rejects_identity_collision_before_mutating_another_row():
    cursor = CursorDouble([(540979,)])
    with pytest.raises(ValueError, match="Conflito de identidade/URI"):
        MySQLLoader._upsert_project(cursor, project_record())
    assert len(cursor.executed) == 1
    assert "SELECT id_projeto FROM projeto_lei" in cursor.executed[0][0]


def test_author_upsert_rejects_uri_collision_before_mutating_another_row():
    cursor = CursorDouble([(160666,)])
    author = {
        "id_autor": 999999,
        "nome": "Autor de teste",
        "tipo": "Deputado",
        "uri_api": "https://dadosabertos.camara.leg.br/api/v2/deputados/160666",
    }
    with pytest.raises(ValueError, match="Conflito de identidade/URI"):
        MySQLLoader._upsert_author(cursor, author)
    assert len(cursor.executed) == 1
    assert "SELECT id_autor FROM autor" in cursor.executed[0][0]


def test_successful_execution_record_commits_atomically_with_etl_data(monkeypatch):
    import types
    import etl.load as load_module

    events = []

    class ConnectionDouble:
        def cursor(self):
            return CursorDouble([])

        def commit(self):
            events.append("commit")

        def rollback(self):
            events.append("rollback")

        def close(self):
            events.append("close")

    connection = ConnectionDouble()
    fake_connector = types.SimpleNamespace(connect=lambda **kwargs: connection)
    monkeypatch.setattr(load_module, "mysql", types.SimpleNamespace(connector=fake_connector))
    monkeypatch.setattr(
        MySQLLoader,
        "_upsert_project",
        staticmethod(lambda cursor, record: events.append("project_upsert")),
    )
    monkeypatch.setattr(
        MySQLLoader,
        "_update_execution",
        staticmethod(lambda cursor, *args, **kwargs: events.append("execution_status")),
    )

    result = MySQLLoader({"host": "db", "user": "test"}).load(
        {"registros": [project_record()]},
        execution_id="execution-test",
        extracted_count=1,
        transformed_count=1,
    )

    assert result["proposicoes"] == 1
    assert events.index("project_upsert") < events.index("execution_status")
    assert events.index("execution_status") < events.index("commit")
    assert events.count("commit") == 1


def test_load_failure_is_not_masked_if_error_status_cannot_be_saved(monkeypatch):
    import types

    import etl.load as load_module

    events = []

    class ConnectionDouble:
        def cursor(self):
            return CursorDouble([])

        def commit(self):
            events.append("commit")

        def rollback(self):
            events.append("rollback")

        def close(self):
            events.append("close")

    connection = ConnectionDouble()
    fake_connector = types.SimpleNamespace(connect=lambda **kwargs: connection)
    monkeypatch.setattr(load_module, "mysql", types.SimpleNamespace(connector=fake_connector))

    def fail_upsert(cursor, record):
        raise ValueError("upsert original failure")

    def fail_status(cursor, *args, **kwargs):
        raise RuntimeError("secondary status-write failure")

    monkeypatch.setattr(MySQLLoader, "_upsert_project", staticmethod(fail_upsert))
    monkeypatch.setattr(MySQLLoader, "_update_execution", staticmethod(fail_status))

    with pytest.raises(ValueError, match="upsert original failure") as caught:
        MySQLLoader({"host": "db", "user": "test"}).load(
            {"registros": [project_record()]}, execution_id="execution-test"
        )

    assert "secondary status-write failure" in " ".join(getattr(caught.value, "__notes__", []))
    assert "rollback" in events
    assert "commit" not in events
