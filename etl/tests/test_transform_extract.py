from __future__ import annotations

from datetime import date
from pathlib import Path

from etl.extract import (
    CamaraExtractor,
    ExtractionConfig,
    JsonlStatusLog,
    expand_filter_profiles,
)
from etl.transform import classify, extract_law, transform_record, valid_tramitacoes


class FakeResponse:
    def __init__(self, payload, status_code=200, url="https://example.test"):
        self._payload = payload
        self.status_code = status_code
        self.url = url

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")

    def json(self):
        return self._payload


class FakeSession:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def get(self, url, params=None, timeout=None):
        self.calls.append((url, params, timeout))
        item = self.responses.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


def record_with_status(code, description, history=None):
    return transform_record(
        {
            "proposicao": {
                "dados": {
                    "id": 1,
                    "siglaTipo": "PL",
                    "numero": 1,
                    "ano": 2024,
                    "ementa": "Teste",
                    "dataApresentacao": "2024-01-01T00:00",
                    "uri": "https://example.test/proposicoes/1",
                    "statusProposicao": {
                        "codSituacao": code,
                        "descricaoSituacao": description,
                    },
                }
            },
            "autores": {"dados": []},
            "tramitacoes": {"dados": history or []},
        }
    )


def test_classification_uses_current_state_not_old_history():
    history = [
        {
            "sequencia": 1,
            "dataHora": "2024-01-01T00:00",
            "codSituacao": 900,
            "descricaoSituacao": "Arquivada",
            "descricaoTramitacao": "Arquivamento",
        },
        {
            "sequencia": 2,
            "dataHora": "2024-02-01T00:00",
            "codSituacao": 924,
            "descricaoSituacao": "Pronta para Pauta",
            "descricaoTramitacao": "Inclusão em pauta",
        },
    ]
    result = record_with_status(None, None, history)
    assert result["status_interno"] == "PRONTA_PARA_PAUTA"
    assert result["vigencia_verificada"] is False


def test_classification_maps_senate_and_norm():
    assert record_with_status(926, "Aguardando Apreciação pelo Senado")["status_interno"] == "AGUARDANDO_SENADO"
    assert record_with_status(1140, "Transformado em Norma Jurídica")["status_interno"] == "TRANSFORMADA_EM_NORMA"


def test_conflicting_current_code_and_description_are_unknown():
    assert record_with_status(1140, "Aguardando Encaminhamento")["status_interno"] == "DESCONHECIDA"
    assert record_with_status(1140, "Transformação em Norma Jurídica")["status_interno"] == "TRANSFORMADA_EM_NORMA"


def test_extract_law_accepts_official_number_formats():
    assert extract_law(["Transformado na Lei Ordinária 14877/2024. DOU 05/06/2024."]) == {
        "lei_numero": "14877/2024",
        "lei_tipo": "Ordinária",
        "lei_data_publicacao": __import__("datetime").date(2024, 6, 5),
    }
    assert extract_law(["Lei nº 14.877/2024, publicada no Diário Oficial da União em 2024-06-05."]) == {
        "lei_numero": "14877/2024",
        "lei_tipo": None,
        "lei_data_publicacao": __import__("datetime").date(2024, 6, 5),
    }
    assert extract_law(["Lei Complementar n° 123 de 2024. DOU 01/02/2024."])["lei_numero"] == "123/2024"


def test_extract_law_accepts_full_legal_date_format():
    law = extract_law(["Transformado na Lei nº 14.877, de 28 de maio de 2024."])
    assert law["lei_numero"] == "14877/2024"


def test_transform_only_infers_law_from_explicit_norm_conversion():
    history = [
        {
            "sequencia": 1,
            "dataHora": "2024-01-01T10:00",
            "despacho": "Altera a Lei Complementar 123/2006.",
        },
        {
            "sequencia": 2,
            "dataHora": "2024-02-01T10:00",
            "despacho": "Transformado na Lei Ordinária 14877/2024. DOU 05/06/2024.",
        },
    ]
    transformed = record_with_status(1140, "Transformado em Norma Jurídica", history)
    assert transformed["lei_numero"] == "14877/2024"
    assert transformed["lei_tipo"] == "Ordinária"
    assert transformed["lei_data_publicacao"] == date(2024, 6, 5)

    active = record_with_status(910, "Aguardando Encaminhamento", history)
    assert active["status_interno"] == "EM_TRAMITACAO"
    assert active["lei_numero"] is None

    unrelated_law = record_with_status(
        1140,
        "Transformado em Norma Jurídica",
        [
            {
                "sequencia": 1,
                "dataHora": "2024-02-01T10:00",
                "despacho": "Transformado em norma jurídica com base na Lei Complementar 123/2006.",
            }
        ],
    )
    assert unrelated_law["lei_numero"] is None


def test_desarquivada_is_not_classified_as_archived():
    result = record_with_status(None, "Proposição desarquivada")
    assert result["status_interno"] == "EM_TRAMITACAO"


def test_approval_is_separate_from_norm_conversion():
    assert record_with_status(None, "Aprovada pelo Plenário")["status_interno"] == "APROVADA"
    assert record_with_status(1140, "Transformado em Norma Jurídica")["status_interno"] == "TRANSFORMADA_EM_NORMA"
    assert record_with_status(None, "Aprovado requerimento de urgência")["status_interno"] == "EM_TRAMITACAO"


def test_terminal_and_unknown_states_are_not_collapsed_into_tramitacao():
    assert classify(None, "Proposição rejeitada pelo plenário", []) == "REJEITADA"
    assert classify(None, "Proposição prejudicada", []) == "PREJUDICADA"
    assert classify(None, "Proposição arquivada", []) == "ARQUIVADA"
    assert classify(None, "Situação administrativa não catalogada", []) == "DESCONHECIDA"


def test_official_codes_require_matching_official_description():
    assert classify(924, "Pronta para Pauta", []) == "PRONTA_PARA_PAUTA"
    assert classify(926, "Aguardando Apreciação pelo Senado Federal", []) == "AGUARDANDO_SENADO"
    assert classify(1140, "Transformado em Norma Jurídica", []) == "TRANSFORMADA_EM_NORMA"
    assert classify(924, "Aguardando Encaminhamento", []) == "DESCONHECIDA"


def test_duplicate_tramitacao_sequence_is_collapsed():
    rows = valid_tramitacoes(
        [
            {"sequencia": 4, "descricaoSituacao": "Antiga"},
            {"sequencia": 4, "descricaoSituacao": "Corrigida"},
        ]
    )
    assert len(rows) == 1
    assert rows[0]["descricao_situacao"] == "Corrigida"


def test_recent_filter_expands_to_api_supported_date_windows():
    filters = expand_filter_profiles(
        [{"siglaTipo": "PL", "periodo_recente_meses": 12}],
        today=date(2026, 10, 9),
    )
    assert filters[0]["dataApresentacaoInicio"] == "2025-10-09"
    assert filters[-1]["dataApresentacaoFim"] == "2026-10-09"
    assert len(filters) == 4
    assert all("periodo_recente_meses" not in item for item in filters)


def test_old_activity_filter_uses_supported_tramitation_dates():
    filters = expand_filter_profiles(
        [{"siglaTipo": "PL", "periodo_tramitacao_meses": 3}],
        today=date(2026, 10, 9),
    )
    assert len(filters) == 1
    assert filters[0]["dataInicio"] == "2026-07-09"
    assert filters[0]["dataFim"] == "2026-10-09"
    assert "dataApresentacaoInicio" not in filters[0]


def test_historical_year_is_chunked_into_supported_presentation_windows():
    filters = expand_filter_profiles(
        [{"siglaTipo": "PL", "historico_ano": 2024}],
        today=date(2026, 10, 9),
    )
    assert len(filters) == 4
    assert filters[0]["dataApresentacaoInicio"] == "2024-01-01"
    assert filters[-1]["dataApresentacaoFim"] == "2024-12-31"
    assert all("dataInicio" not in item for item in filters)


def test_extractor_retries_and_paginates(tmp_path: Path):
    session = FakeSession(
        [
            FakeResponse({}, status_code=503),
            FakeResponse({"dados": [{"id": 1}]}),
            FakeResponse({"dados": []}),
        ]
    )
    extractor = CamaraExtractor(
        ExtractionConfig(
            base_url="https://example.test",
            max_retries=1,
            backoff_seconds=0,
            page_size=1,
            max_pages=3,
        ),
        JsonlStatusLog(tmp_path / "status.jsonl"),
        session=session,
    )
    candidates = extractor.list_candidates({"siglaTipo": "PL"})
    assert candidates == [{"id": 1}]
    assert len(session.calls) == 3
    assert session.calls[0][1]["pagina"] == 1
    assert session.calls[-1][1]["pagina"] == 2


def test_extractor_rejects_invalid_page_size(tmp_path: Path):
    try:
        ExtractionConfig(base_url="https://example.test", page_size=101)
    except ValueError as exc:
        assert "page_size" in str(exc)
    else:
        raise AssertionError("page_size acima de 100 deveria falhar")


def test_extractor_marks_full_last_page_as_partial(tmp_path: Path):
    session = FakeSession(
        [
            FakeResponse({"dados": [{"id": 1}]}),
            FakeResponse({"dados": {"id": 1, "siglaTipo": "PL", "numero": 1, "ano": 2024}}),
            FakeResponse({"dados": []}),
            FakeResponse({"dados": []}),
        ]
    )
    extractor = CamaraExtractor(
        ExtractionConfig(
            base_url="https://example.test",
            max_retries=0,
            page_size=1,
            max_pages=1,
        ),
        JsonlStatusLog(tmp_path / "status.jsonl"),
        session=session,
    )
    payload = extractor.run([{"siglaTipo": "PL"}])
    assert payload["paginas_processadas"] == 1
    assert payload["coleta_parcial"] is True
    assert payload["avisos"]
    assert "incompleta" in payload["avisos"][0]


def test_current_status_description_wins_over_conflicting_old_or_latest_dispatch():
    history = [
        {
            "sequencia": 1,
            "dataHora": "2024-01-01T10:00",
            "descricaoSituacao": "Transformado em Norma Jurídica",
            "descricaoTramitacao": "Transformação em Norma Jurídica",
            "despacho": "Transformado na Lei Ordinária 14877/2024.",
        },
        {
            "sequencia": 2,
            "dataHora": "2024-02-01T10:00",
            "descricaoSituacao": "Aguardando Encaminhamento",
            "descricaoTramitacao": "Encaminhamento para análise",
            "despacho": "Aguardando decisão administrativa",
        },
    ]
    assert classify(910, "Aguardando Encaminhamento", history) == "EM_TRAMITACAO"
    assert classify(None, "Situação futura desconhecida", history) == "DESCONHECIDA"


def test_tramitacoes_are_ordered_by_official_sequence_even_without_date():
    rows = valid_tramitacoes(
        [
            {
                "sequencia": 1,
                "dataHora": "2024-10-01T10:00",
                "descricaoSituacao": "Transformado em Norma Jurídica",
            },
            {
                "sequencia": 2,
                "dataHora": None,
                "descricaoSituacao": "Aguardando Encaminhamento",
            },
        ]
    )
    assert [row["sequencia"] for row in rows] == [1, 2]
    assert classify(None, None, rows) == "EM_TRAMITACAO"
