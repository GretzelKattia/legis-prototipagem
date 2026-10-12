from datetime import date

import pytest
import requests

from app.services.legal_evidence import fetch_verified_evidence

EXCERPT = "Situação: Vigente no registro oficial da norma consultada"
HTML = (
    "<html><body><h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>"
    f"<p>{EXCERPT}</p><p>Art. 8º Esta Lei entra em vigor na data de sua publicação.</p>"
    "</body></html>"
).encode()


class MockResponse:
    status_code = 200
    url = "https://www2.camara.leg.br/norma.html"
    content = HTML
    encoding = "utf-8"

    def raise_for_status(self):
        return None


class MockSession:
    def __init__(self, response=None, error=None):
        self.response = response
        self.error = error
        self.calls = []

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if self.error:
            raise self.error
        return self.response


def args(**overrides):
    values = {
        "source_url": "https://www2.camara.leg.br/norma.html",
        "law_number": "14877/2024",
        "legal_state": "VIGENTE",
        "evidence_excerpt": EXCERPT,
        "effective_date": date(2024, 6, 5),
        "publication_date": date(2024, 6, 5),
    }
    values.update(overrides)
    return values


def test_evidence_records_real_http_and_content_hash():
    session = MockSession(response=MockResponse())
    result = fetch_verified_evidence(**args(), session=session)
    assert result["resposta_http"] == 200
    assert len(result["conteudo_sha256"]) == 64
    assert result["verificada_em"].utcoffset().total_seconds() == 0
    assert session.calls[0][1]["allow_redirects"] is False


def test_evidence_rejects_non_official_domain():
    with pytest.raises(ValueError, match="domínio oficial"):
        fetch_verified_evidence(**args(source_url="https://planalto.gov.br.evil.example/norma"))


def test_evidence_rejects_quote_not_in_source():
    with pytest.raises(ValueError, match="não foi encontrado"):
        fetch_verified_evidence(
            **args(evidence_excerpt="Lei nº 14.877 não está citada aqui, embora tenha mais de quarenta caracteres."),
            session=MockSession(response=MockResponse()),
        )


def test_evidence_rejects_bad_http_response():
    error_response = requests.Response()
    error_response.status_code = 503
    error = requests.HTTPError("HTTP 503", response=error_response)
    with pytest.raises(requests.HTTPError):
        fetch_verified_evidence(**args(), session=MockSession(error=error))


def test_entry_into_force_clause_alone_does_not_verify_current_vigency():
    with pytest.raises(ValueError, match="marcar vigência atual"):
        fetch_verified_evidence(
            **args(evidence_excerpt="Art. 8º Esta Lei entra em vigor na data de sua publicação."),
            session=MockSession(response=MockResponse()),
        )


def test_official_no_express_repeal_state_is_recordable_without_calling_it_vigente():
    quote = "Situação: Não consta revogação expressa Indexação CACAUICULTURA"
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    result = fetch_verified_evidence(
        **args(legal_state="NAO_CONSTA_REVOGACAO_EXPRESSA", evidence_excerpt=quote),
        session=MockSession(response=response),
    )
    assert result["situacao_juridica"] == "NAO_CONSTA_REVOGACAO_EXPRESSA"


def test_revocation_state_rejects_negated_revocation_excerpt():
    quote = "A norma não foi revogada expressamente e segue mencionada no registro oficial."
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    with pytest.raises(ValueError, match="evidência afirmativa e vinculada de revogação"):
        fetch_verified_evidence(
            **args(legal_state="REVOGADA", evidence_excerpt=quote),
            session=MockSession(response=response),
        )


def test_partial_vigency_rejects_negated_phrase():
    quote = "A lei não está parcialmente vigente conforme o registro oficial publicado."
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    with pytest.raises(ValueError, match="não sustenta vigência parcial"):
        fetch_verified_evidence(
            **args(legal_state="PARCIALMENTE_VIGENTE", evidence_excerpt=quote),
            session=MockSession(response=response),
        )


def test_vacatio_requires_explicit_future_effective_date_and_entry_into_force_text():
    quote = "Esta norma poderá ser aplicada após a revisão administrativa do documento oficial."
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    with pytest.raises(ValueError, match="entrada em vigor futura"):
        fetch_verified_evidence(
            **args(
                legal_state="VACATIO_LEGIS",
                evidence_excerpt=quote,
                effective_date=date(2027, 1, 1),
            ),
            session=MockSession(response=response),
        )


def test_expired_vacatio_cannot_be_recorded_as_current_vacatio():
    with pytest.raises(ValueError, match="ainda futura"):
        fetch_verified_evidence(
            **args(
                legal_state="VACATIO_LEGIS",
                evidence_excerpt="A lei entrará em vigor após trinta dias da publicação oficial.",
                effective_date=date(2024, 7, 5),
            ),
            session=MockSession(response=MockResponse()),
        )


def test_unrelated_official_page_cannot_pass_by_containing_target_number_in_a_link():
    quote = EXCERPT
    response = MockResponse()
    response.content = (
        '<html><head><title>Lei nº 10.000, de 2020</title></head>'
        '<body><h1>Lei nº 10.000, de 2020</h1>'
        '<a href="/legislacao/lei-14877-2024">Lei 14.877/2024</a>'
        f'<p>{quote}</p></body></html>'
    ).encode()
    with pytest.raises(ValueError, match="número e o ano da norma"):
        fetch_verified_evidence(**args(), session=MockSession(response=response))


def test_revocation_requires_specific_law_or_explicit_status_label():
    quote = "O artigo de uma norma relacionada foi revogado após alteração legislativa recente."
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    with pytest.raises(ValueError, match="vinculada de revogação"):
        fetch_verified_evidence(
            **args(legal_state="REVOGADA", evidence_excerpt=quote),
            session=MockSession(response=response),
        )


def test_vacatio_requires_clause_about_target_law_not_unrelated_law():
    quote = "A outra lei entrará em vigor após trinta dias da publicação oficial."
    response = MockResponse()
    response.content = (
        "<h1>LEI Nº 14.877, DE 4 DE JUNHO DE 2024</h1>" f"<p>{quote}</p>"
    ).encode()
    with pytest.raises(ValueError, match="norma consultada"):
        fetch_verified_evidence(
            **args(
                legal_state="VACATIO_LEGIS",
                evidence_excerpt=quote,
                effective_date=date(2027, 1, 1),
            ),
            session=MockSession(response=response),
        )
