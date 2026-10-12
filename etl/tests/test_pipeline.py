from __future__ import annotations

import json

import pytest
import requests

from etl.extract import CamaraExtractor
from etl.pipeline import run


class Response:
    def __init__(self, payload, status=200, url="https://camara.test"):
        self.payload = payload
        self.status_code = status
        self.url = url

    def raise_for_status(self):
        if self.status_code >= 400:
            response = requests.Response()
            response.status_code = self.status_code
            response.url = self.url
            raise requests.HTTPError(f"HTTP {self.status_code}", response=response)

    def json(self):
        return self.payload


class Session:
    def __init__(self, results):
        self.results = iter(results)
        self.calls = []

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs.get("params")))
        return next(self.results)


class Loader:
    instances = []

    def __init__(self, connection_config):
        self.connection_config = connection_config
        self.loaded = None
        self.finished = []
        self.instances.append(self)

    def start_execution(self, filters):
        self.filters = filters
        return "execution-test", None

    def load(self, payload, filters, **kwargs):
        self.loaded = (payload, filters, kwargs)
        return {"id_execucao": "execution-test", "proposicoes": len(payload["registros"])}

    def finish_execution(self, *args, **kwargs):
        self.finished.append((args, kwargs))


def sample_detail_responses():
    return [
        Response(
            {
                "dados": {
                    "id": 540979,
                    "siglaTipo": "PL",
                    "numero": 2913,
                    "ano": 2021,
                    "ementa": "Selo verde",
                    "uri": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/540979",
                    "dataApresentacao": "2021-01-01T12:00",
                    "statusProposicao": {
                        "codSituacao": 1140,
                        "descricaoSituacao": "Transformado em Norma Jurídica",
                        "despacho": "Transformado na Lei Ordinária 14877/2024.",
                    },
                }
            }
        ),
        Response({"dados": []}),
        Response(
            {
                "dados": [
                    {"sequencia": 144, "descricaoSituacao": "Transformada em Norma"},
                    {"sequencia": 144, "descricaoSituacao": "Transformada em Norma revisada"},
                ]
            }
        ),
    ]


def make_config(tmp_path, *, max_retries=0):
    path = tmp_path / "config.json"
    (tmp_path / "status.jsonl").write_text("", encoding="utf-8")
    path.write_text(
        json.dumps(
            {
                "api": {
                    "base_url": "https://camara.test/api/v2",
                    "timeout_seconds": 1,
                    "max_retries": max_retries,
                    "backoff_seconds": 0,
                    "page_size": 100,
                    "max_pages": 2,
                },
                "filters": [{"siglaTipo": "PL"}, {"siglaTipo": "PLP"}],
                "status_internos_incluidos": ["TRANSFORMADA_EM_NORMA"],
                "database": {"host": "db.test"},
                "paths": {
                    "status_log": str(tmp_path / "status.jsonl"),
                    "raw_output": str(tmp_path / "raw.json"),
                    "transformed_output": str(tmp_path / "transformed.json"),
                },
            }
        ),
        encoding="utf-8",
    )
    return path


def test_pipeline_fetches_deduplicates_transforms_and_loads(monkeypatch, tmp_path):
    Loader.instances.clear()
    session = Session(
        [
            Response({"dados": [{"id": 540979}]}),
            Response({"dados": [{"id": 540979}]}),
            *sample_detail_responses(),
        ]
    )
    monkeypatch.setattr("etl.pipeline.MySQLLoader", Loader)
    monkeypatch.setattr(
        "etl.pipeline.CamaraExtractor",
        lambda config, status_log: CamaraExtractor(config, status_log, session=session),
    )

    result = run(str(make_config(tmp_path)))

    assert result["extraidos"] == 1
    assert result["transformados"] == 1
    assert result["coleta_parcial"] is False
    assert result["carga"]["proposicoes"] == 1
    assert len(session.calls) == 5  # duas listas e só três detalhes do ID deduplicado
    record = Loader.instances[-1].loaded[0]["registros"][0]
    assert record["status_interno"] == "TRANSFORMADA_EM_NORMA"
    assert [tram["sequencia"] for tram in record["tramitacoes"]] == [144]
    assert record["vigencia_verificada"] is False


def test_pipeline_propagates_http_failure_and_records_failed_execution(
    monkeypatch, tmp_path
):
    Loader.instances.clear()
    session = Session([Response({"title": "Unavailable"}, status=503)])
    monkeypatch.setattr("etl.pipeline.MySQLLoader", Loader)
    monkeypatch.setattr(
        "etl.pipeline.CamaraExtractor",
        lambda config, status_log: CamaraExtractor(config, status_log, session=session),
    )

    with pytest.raises(requests.HTTPError):
        run(str(make_config(tmp_path)))

    loader = Loader.instances[-1]
    assert loader.loaded is None
    assert loader.finished
    assert json.loads((tmp_path / "status.jsonl").read_text().splitlines()[-1])["event"] == "pipeline_error"


def test_pipeline_logs_error_when_mysql_execution_registration_fails(monkeypatch, tmp_path):
    class UnavailableLoader:
        def __init__(self, connection_config):
            pass

        def start_execution(self, filters):
            raise RuntimeError("database unavailable")

    monkeypatch.setattr("etl.pipeline.MySQLLoader", UnavailableLoader)
    with pytest.raises(RuntimeError, match="database unavailable"):
        run(str(make_config(tmp_path)))

    last_event = json.loads((tmp_path / "status.jsonl").read_text().splitlines()[-1])
    assert last_event["event"] == "pipeline_error"
    assert "database unavailable" in last_event["error"]


def test_pipeline_preserves_original_error_if_mysql_error_logging_fails(monkeypatch, tmp_path):
    class BrokenExecutionLogLoader(Loader):
        def start_execution(self, filters):
            return "execution-test", None

        def finish_execution(self, *args, **kwargs):
            raise RuntimeError("database logging unavailable")

    session = Session([Response({"title": "Unavailable"}, status=503)])
    monkeypatch.setattr("etl.pipeline.MySQLLoader", BrokenExecutionLogLoader)
    monkeypatch.setattr(
        "etl.pipeline.CamaraExtractor",
        lambda config, status_log: CamaraExtractor(config, status_log, session=session),
    )

    with pytest.raises(requests.HTTPError):
        run(str(make_config(tmp_path)))

    last_event = json.loads((tmp_path / "status.jsonl").read_text().splitlines()[-1])
    assert last_event["event"] == "pipeline_error"
    assert "database logging unavailable" in last_event["execution_log_error"]


def test_pipeline_loads_records_hidden_from_presentation(monkeypatch, tmp_path):
    Loader.instances.clear()
    session = Session(
        [
            Response({"dados": [{"id": 540979}]}),
            Response({"dados": []}),
            Response({"dados": {"id": 540979, "siglaTipo": "PL", "numero": 2913,
                                  "ano": 2021, "ementa": "Selo verde",
                                  "dataApresentacao": "2021-01-01T12:00",
                                  "uri": "https://camara.test/p/540979",
                                  "statusProposicao": {"codSituacao": 900,
                                                        "descricaoSituacao": "Arquivada"}}}),
            Response({"dados": []}),
            Response({"dados": []}),
        ]
    )
    monkeypatch.setattr("etl.pipeline.MySQLLoader", Loader)
    monkeypatch.setattr("etl.pipeline.CamaraExtractor",
                        lambda config, status_log: CamaraExtractor(config, status_log, session=session))
    result = run(str(make_config(tmp_path)))
    assert result["transformados"] == 1
    assert result["apresentaveis"] == 0
    assert len(Loader.instances[-1].loaded[0]["registros"]) == 1


def test_pipeline_can_separately_limit_persistence_for_historical_backfill(
    monkeypatch, tmp_path
):
    Loader.instances.clear()

    class Extractor:
        def __init__(self, config, status_log):
            pass

        def run(self, filters):
            return {
                "registros": [{"raw": 1}, {"raw": 2}],
                "paginas_processadas": 1,
                "coleta_parcial": False,
                "avisos": [],
            }

    records = [
        {"id_projeto": 1, "status_interno": "TRANSFORMADA_EM_NORMA"},
        {"id_projeto": 2, "status_interno": "ARQUIVADA"},
    ]
    monkeypatch.setattr("etl.pipeline.MySQLLoader", Loader)
    monkeypatch.setattr("etl.pipeline.CamaraExtractor", Extractor)
    monkeypatch.setattr(
        "etl.pipeline.transform_payload",
        lambda extracted: {"registros": records},
    )

    result = run(
        str(make_config(tmp_path)),
        included_statuses_override=["TRANSFORMADA_EM_NORMA"],
        persist_statuses_override=["TRANSFORMADA_EM_NORMA"],
    )

    loaded_payload, _, load_kwargs = Loader.instances[-1].loaded
    assert result["transformados"] == 2
    assert result["apresentaveis"] == 1
    assert [row["id_projeto"] for row in loaded_payload["registros"]] == [1]
    assert load_kwargs["transformed_count"] == 2


def test_historical_backfill_explicitly_filters_persisted_statuses(monkeypatch):
    from etl import backfill as backfill_module

    calls = []

    def fake_run(config_path, **kwargs):
        calls.append(kwargs)
        return {"coleta_parcial": False}

    monkeypatch.setattr(backfill_module, "run", fake_run)
    backfill_module.backfill("test-config.json", 2025, 2025)

    assert calls[0]["included_statuses_override"] == ["TRANSFORMADA_EM_NORMA"]
    assert calls[0]["persist_statuses_override"] == ["TRANSFORMADA_EM_NORMA"]


def test_mid_page_failure_records_progress_and_partial_status(monkeypatch, tmp_path):
    Loader.instances.clear()
    session = Session(
        [
            Response({"dados": [{"id": 540979}]}),
            Response({"title": "Unavailable"}, status=503),
        ]
    )
    monkeypatch.setattr("etl.pipeline.MySQLLoader", Loader)
    monkeypatch.setattr(
        "etl.pipeline.CamaraExtractor",
        lambda config, status_log: CamaraExtractor(config, status_log, session=session),
    )
    config_path = make_config(tmp_path)
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config["filters"] = [{"siglaTipo": "PL"}]
    config["api"]["page_size"] = 1
    config["api"]["max_pages"] = 2
    config_path.write_text(json.dumps(config), encoding="utf-8")

    with pytest.raises(requests.HTTPError):
        run(str(config_path))

    loader = Loader.instances[-1]
    _, kwargs = loader.finished[-1]
    assert kwargs["pages"] == 1
    assert kwargs["partial"] is True
    event = json.loads((tmp_path / "status.jsonl").read_text().splitlines()[-1])
    assert event["paginas_processadas"] == 1
    assert event["coleta_parcial"] is True
    assert "base completa" in event["avisos"][-1]
