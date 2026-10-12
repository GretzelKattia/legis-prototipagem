"""Consulta verificável de evidências jurídicas em fontes oficiais.

A existência de uma lei ou sua conversão em norma não é prova de vigência.
O status é sempre informado por um revisor administrativo e exige um trecho
exato encontrado no conteúdo oficial consultado.
"""

from __future__ import annotations

import hashlib
import html
import re
import unicodedata
from datetime import date, datetime, timezone
from urllib.parse import urlparse

import requests

OFFICIAL_HOSTS = (
    "planalto.gov.br",
    "camara.leg.br",
    "senado.leg.br",
    "in.gov.br",
    "presidencia.gov.br",
    "lexml.gov.br",
)
LEGAL_STATES = {
    "VIGENTE",
    "NAO_CONSTA_REVOGACAO_EXPRESSA",
    "PARCIALMENTE_VIGENTE",
    "REVOGADA",
    "VACATIO_LEGIS",
}


def _is_official_host(host: str | None) -> bool:
    host = (host or "").lower().rstrip(".")
    return any(host == root or host.endswith("." + root) for root in OFFICIAL_HOSTS)


def _plain_text(value: str) -> str:
    value = re.sub(r"(?is)<(script|style).*?</\1>", " ", value)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", value).strip().casefold()



def _law_identity_present(text: str, law_number: str) -> bool:
    """Match a specific law number/year, not a coincidental digit substring."""
    parts = law_number.split("/", 1)
    if len(parts) != 2:
        return False
    number = re.sub(r"\D", "", parts[0])
    year = re.sub(r"\D", "", parts[1])
    if len(number) < 3 or len(year) != 4:
        return False
    if len(number) > 3:
        number_pattern = rf"(?:{re.escape(number)}|{re.escape(number[:-3])}\.?\s*{re.escape(number[-3:])})"
    else:
        number_pattern = re.escape(number)
    law_pattern = re.compile(
        rf"\blei\s+(?:(?:complementar|ordinaria|federal)\s+)?"
        rf"(?:n[ºo.]?\s*)?{number_pattern}"
        rf"(?:\s*/\s*{re.escape(year)}\b|"
        rf",?\s+de\s+(?:\d{{1,2}}\s+de\s+[a-z]+\s+de\s+)?{re.escape(year)}\b)",
        re.IGNORECASE,
    )
    return bool(law_pattern.search(text))


def _page_heading_text(body: str) -> str:
    headings = re.findall(
        r"(?is)<(?:title|h1|h2)\b[^>]*>(.*?)</(?:title|h1|h2)\s*>", body
    )
    return _plain_text(" ".join(headings))

def _has_affirmative_revocation(text: str) -> bool:
    """Return true only for an affirmative, not-negated revocation statement."""
    if not re.search(r"\brevogad[oa]s?\b", text):
        return False
    if re.search(
        r"\b(?:nao|sem|inexistencia de|ausencia de)\b.{0,70}\brevogad[oa]s?\b",
        text,
    ):
        return False
    if re.search(
        r"\b(?:sera|seria|podera|poderia|pode|podera vir a ser|pode vir a ser)\b"
        r".{0,30}\brevogad[oa]s?\b",
        text,
    ):
        return False
    return True


def _supports_revoked(text: str, law_number: str) -> bool:
    if not _has_affirmative_revocation(text):
        return False
    # A generic mention that *some* legal provision was revoked is not enough.
    # Require an explicit status label or identify the requested law in the quote.
    explicit_status = re.search(
        r"\b(?:situacao(?: da norma)?|status)(?: oficial)?\s*:\s*revogad[oa]\b",
        text,
    )
    return bool(explicit_status or _law_identity_present(text, law_number))


def _supports_partial_vigency(text: str, law_number: str) -> bool:
    if re.search(
        r"\b(?:nao|sem|inexistencia de|ausencia de)\b.{0,60}"
        r"(?:parcialmente vigente|vigente em parte|vigencia parcial|revogacao parcial|"
        r"revogad[oa]s? parcialmente)\b",
        text,
    ):
        return False
    partial_phrase = any(
        phrase in text
        for phrase in ("parcialmente vigente", "vigente em parte", "vigencia parcial", "revogacao parcial")
    ) or bool(re.search(r"\brevogad[oa]s? parcialmente\b", text) and _has_affirmative_revocation(text))
    if not partial_phrase:
        return False
    explicit_status = re.search(
        r"\b(?:situacao(?: da norma)?|status)(?: oficial)?\s*:\s*"
        r"(?:parcialmente vigente|vigente em parte|vigencia parcial)\b",
        text,
    )
    target_is_named = _law_identity_present(text, law_number) or bool(
        re.search(r"\besta (?:lei|norma)\b", text)
    )
    return bool(explicit_status or target_is_named)


def _supports_vacatio(text: str, law_number: str) -> bool:
    if re.search(
        r"\bnao\b.{0,40}\b(?:entrara em vigor|passara a vigorar|vigencia a partir de)\b",
        text,
    ):
        return False
    entry_clause = any(
        phrase in text
        for phrase in (
            "entrara em vigor apos",
            "entrara em vigor em",
            "entrara em vigor no dia",
            "passara a vigorar em",
            "passara a vigorar apos",
            "vigencia a partir de",
        )
    )
    target_is_named = _law_identity_present(text, law_number) or bool(
        re.search(r"\besta (?:lei|norma)\b", text)
    )
    return entry_clause and target_is_named


def fetch_verified_evidence(
    *,
    source_url: str,
    law_number: str,
    legal_state: str,
    evidence_excerpt: str,
    effective_date: date | None,
    publication_date: date | None,
    timeout: tuple[float, float] = (5.0, 20.0),
    session: requests.Session | None = None,
) -> dict:
    """Consulta fonte oficial e exige número e citação literal no HTML retornado."""
    parsed = urlparse(source_url)
    if parsed.scheme != "https" or not _is_official_host(parsed.hostname):
        raise ValueError("A fonte deve ser HTTPS em domínio oficial permitido")
    if legal_state not in LEGAL_STATES:
        raise ValueError("Situação jurídica não reconhecida")
    if not 40 <= len(evidence_excerpt.strip()) <= 1500:
        raise ValueError("A evidência deve conter entre 40 e 1.500 caracteres")
    if legal_state in {"VIGENTE", "VACATIO_LEGIS"} and effective_date is None:
        raise ValueError("Informe o início da vigência indicado pela fonte oficial")
    if effective_date and publication_date and effective_date < publication_date:
        raise ValueError("O início da vigência não pode anteceder a publicação")
    if legal_state == "VIGENTE" and effective_date and effective_date > date.today():
        raise ValueError("Uma norma com início futuro não pode ser marcada como vigente")
    if legal_state == "VACATIO_LEGIS" and effective_date and effective_date <= date.today():
        raise ValueError("VACATIO_LEGIS exige data de início da vigência ainda futura")

    client = session or requests.Session()
    response = client.get(
        source_url,
        headers={"Accept": "text/html,application/xhtml+xml", "User-Agent": "LEGIS/1.0"},
        timeout=timeout,
        allow_redirects=False,
    )
    response.raise_for_status()
    if not _is_official_host(urlparse(response.url).hostname):
        raise ValueError("A resposta redirecionou para domínio não oficial")
    if response.status_code != 200:
        raise ValueError(f"Fonte oficial retornou HTTP {response.status_code}, esperado 200")

    body = response.content.decode(response.encoding or "utf-8", errors="replace")
    normalized_body = _plain_text(body)
    normalized_excerpt = _plain_text(evidence_excerpt)
    # The quoted status alone is not enough if the target law appears only in
    # an unrelated link elsewhere on an official page. Require a law number
    # plus its year in the citation or in the page's title/main heading.
    if not (
        _law_identity_present(normalized_excerpt, law_number)
        or _law_identity_present(_page_heading_text(body), law_number)
    ):
        raise ValueError("A fonte consultada não identifica o número e o ano da norma")
    if normalized_excerpt not in normalized_body:
        raise ValueError("O trecho citado não foi encontrado literalmente na fonte consultada")

    if legal_state == "VIGENTE" and not any(
        phrase in normalized_excerpt
        for phrase in (
            "situacao: vigente",
            "situacao da norma: vigente",
            "situacao: em vigor",
            "situacao da norma: em vigor",
            "status: vigente",
            "status: em vigor",
            "esta lei esta em vigor",
            "esta norma esta em vigor",
        )
    ):
        raise ValueError(
            "Para marcar vigência atual, cite status oficial explícito ‘Vigente’ ou ‘Em vigor’; início de vigência ou ausência de revogação, isoladamente, não basta"
        )
    if legal_state == "NAO_CONSTA_REVOGACAO_EXPRESSA" and (
        "nao consta revogacao expressa" not in normalized_excerpt
    ):
        raise ValueError("A citação não confirma a situação oficial informada")
    if legal_state == "REVOGADA" and not _supports_revoked(normalized_excerpt, law_number):
        raise ValueError("A citação não contém evidência afirmativa e vinculada de revogação")
    if legal_state == "PARCIALMENTE_VIGENTE" and not _supports_partial_vigency(normalized_excerpt, law_number):
        raise ValueError("A citação não sustenta vigência parcial vinculada à norma")
    if legal_state == "VACATIO_LEGIS" and not _supports_vacatio(normalized_excerpt, law_number):
        raise ValueError("A citação não sustenta entrada em vigor futura da norma consultada")

    return {
        "fonte_url": response.url,
        "resposta_http": response.status_code,
        "conteudo_sha256": hashlib.sha256(response.content).hexdigest(),
        "verificada_em": datetime.now(timezone.utc),
        "evidencia_texto": evidence_excerpt.strip(),
        "situacao_juridica": legal_state,
        "lei_inicio_vigencia": effective_date,
        "lei_data_publicacao": publication_date,
    }
