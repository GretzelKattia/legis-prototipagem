"""Transformações determinísticas dos dados brutos da API."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

LAW_RE = re.compile(
    r"Lei\s+(?P<tipo>Complementar|Ordinária|Ordinaria|Federal)?\s*"
    r"(?:n[ºo°.]?\s*)?(?P<numero>\d{1,3}(?:\.\d{3})+|\d{1,7})\s*"
    r"(?:/\s*|,?\s*de\s*(?:\d{1,2}\s+de\s+"
    r"(?:janeiro|fevereiro|março|marco|abril|maio|junho|julho|agosto|"
    r"setembro|outubro|novembro|dezembro)\s+de\s*)?)(?P<ano>\d{4})",
    re.I,
)
PUBLICATION_RE = re.compile(
    r"(?:DOU|Diário Oficial(?: da União)?)\D{0,40}"
    r"(\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})",
    re.I,
)
OFFICIAL_SITUATION_CODES = {
    924: "pronta para pauta",
    926: "aguardando apreciação pelo senado federal",
    1140: "transformado em norma jurídica",
}

KNOWN_INTERNAL_STATUSES = {
    "APROVADA",
    "TRANSFORMADA_EM_NORMA",
    "EM_TRAMITACAO",
    "PRONTA_PARA_PAUTA",
    "AGUARDANDO_SENADO",
    "ARQUIVADA",
    "REJEITADA",
    "PREJUDICADA",
    "DESCONHECIDA",
}


def clean_text(value: Any) -> str | None:
    if value is None:
        return None
    value = re.sub(r"\s+", " ", str(value)).strip()
    return value or None


def iso_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    text = str(value).strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def iso_date(value: Any) -> date | None:
    parsed = iso_datetime(value)
    return parsed.date() if parsed else None


def extract_law(despachos: list[str | None]) -> dict[str, Any]:
    text = " ".join(x for x in despachos if x)
    match = LAW_RE.search(text)
    if not match:
        return {"lei_numero": None, "lei_tipo": None, "lei_data_publicacao": None}
    numero = f"{match.group('numero').replace('.', '')}/{match.group('ano')}"
    tipo = clean_text(match.group("tipo"))
    publication = PUBLICATION_RE.search(text)
    publication_date = None
    if publication:
        value = publication.group(1)
        publication_date = (
            datetime.strptime(value, "%d/%m/%Y").date()
            if "/" in value
            else datetime.strptime(value, "%Y-%m-%d").date()
        )
    return {
        "lei_numero": numero,
        "lei_tipo": tipo,
        "lei_data_publicacao": publication_date,
    }


def extract_enacted_law(despachos: list[str | None]) -> dict[str, Any]:
    """Extract a law number only from text explicitly describing enactment.

    Tramitation histories often cite other laws that a proposal intends to
    amend. A generic first-match over the whole history can mistake one of
    those references for the law created by the proposal. When the official
    text does not explicitly connect the number to a transformation event,
    return no inferred law rather than guessing.
    """
    empty = {"lei_numero": None, "lei_tipo": None, "lei_data_publicacao": None}
    transformation = re.compile(
        r"\b(?:transformad[oa]s?|convertid[oa]s?)\s+(?:na|no|em)\s+lei\b"
        r"|\btransforma[cç][aã]o\s+em\s+norma\s+j[uú]r[ií]dica\b.{0,40}\blei\b",
        re.IGNORECASE,
    )
    for raw in despachos:
        text = clean_text(raw)
        if not text:
            continue
        match = transformation.search(text)
        if not match:
            continue
        law = extract_law([text[match.start():]])
        if law["lei_numero"]:
            return law
    return empty


def valid_tramitacoes(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized_by_sequence: dict[int, dict[str, Any]] = {}
    for item in items or []:
        if not isinstance(item, dict) or item.get("sequencia") is None:
            continue
        row = dict(item)
        row["sequencia"] = int(row["sequencia"])
        row["data_hora"] = iso_datetime(row.get("dataHora"))
        row["sigla_orgao"] = clean_text(row.get("siglaOrgao"))
        row["uri_orgao"] = clean_text(row.get("uriOrgao"))
        row["regime"] = clean_text(row.get("regime"))
        row["codigo_tipo_tramitacao"] = row.get("codTipoTramitacao")
        row["codigo_situacao"] = row.get("codSituacao")
        row["descricao_situacao"] = clean_text(row.get("descricaoSituacao"))
        row["descricao_tramitacao"] = clean_text(row.get("descricaoTramitacao"))
        row["despacho"] = clean_text(row.get("despacho"))
        row["uri_ultimo_relator"] = clean_text(row.get("uriUltimoRelator"))
        row["url"] = clean_text(row.get("url"))
        row["ambito"] = clean_text(row.get("ambito"))
        row["apreciacao"] = clean_text(row.get("apreciacao"))
        normalized_by_sequence[row["sequencia"]] = row
    normalized = list(normalized_by_sequence.values())
    # A sequência fornecida pela Câmara é a ordem do histórico. Ordenar
    # primeiro por data poderia deslocar para o início um evento mais novo
    # caso sua data viesse ausente ou corrigida na fonte.
    return sorted(normalized, key=lambda x: x["sequencia"])


def _classify_status_text(value: str | None) -> str:
    """Classify one authoritative status description, never mixed histories."""
    text = clean_text(value)
    if not text:
        return "DESCONHECIDA"
    current_text = text.casefold()

    if any(
        phrase in current_text
        for phrase in (
            "transformado em norma juridica",
            "transformado em norma jurídica",
            "transformacao em norma juridica",
            "transformação em norma jurídica",
        )
    ):
        return "TRANSFORMADA_EM_NORMA"
    if "pronta para pauta" in current_text:
        return "PRONTA_PARA_PAUTA"
    if "aguardando apreciação pelo senado" in current_text or "aguardando apreciacao pelo senado" in current_text:
        return "AGUARDANDO_SENADO"
    if re.search(r"\b(?:rejeitada|rejeitado|rejeição|rejeicao)\b", current_text):
        return "REJEITADA"
    if re.search(r"\b(?:prejudicada|prejudicado|prejudicialidade)\b", current_text):
        return "PREJUDICADA"
    if re.search(r"\b(?:arquivada|arquivado|arquivamento)\b", current_text):
        return "ARQUIVADA"
    if "desarquivada" in current_text or "desarquivado" in current_text:
        return "EM_TRAMITACAO"
    if re.search(r"\baprovad[ao]\s+requerimento\b", current_text):
        return "EM_TRAMITACAO"
    if re.search(
        r"\b(?:projeto(?:\s+de\s+lei)?|proposição|proposta|matéria\s+legislativa)"
        r"\s+(?:foi\s+)?aprovad[ao]s?\b|"
        r"\baprovad[ao]s?\s+(?:no|na|pelo|pela)\s+"
        r"(?:plenário|câmara|senado|congresso|comissão)\b",
        current_text,
    ):
        return "APROVADA"
    if any(
        marker in current_text
        for marker in (
            "em tramitação", "em tramitacao", "aguardando", "em análise",
            "em analise", "pronta para despacho", "aguardando despacho",
        )
    ):
        return "EM_TRAMITACAO"
    return "DESCONHECIDA"


def classify(
    code: int | None, description: str | None, history: list[dict[str, Any]]
) -> str:
    """Prefer the current API status; consult history only when it is absent.

    A past tramitation can mention a completed legal event even when the
    current status differs. Never combine both texts into a single classifier.
    """
    current_description = clean_text(description)
    if current_description:
        # The current description is authoritative over old tramitation text,
        # but a contradiction between two current API fields is ambiguous.
        classified = _classify_status_text(current_description)
        code_status = {
            1140: "TRANSFORMADA_EM_NORMA",
            924: "PRONTA_PARA_PAUTA",
            926: "AGUARDANDO_SENADO",
        }.get(code)
        if code_status is not None and classified != code_status:
            return "DESCONHECIDA"
        return classified

    if code is not None:
        # Known official codes may be used if the API omitted the description.
        if code in OFFICIAL_SITUATION_CODES:
            return {
                1140: "TRANSFORMADA_EM_NORMA",
                924: "PRONTA_PARA_PAUTA",
                926: "AGUARDANDO_SENADO",
            }[code]
        # A present but unrecognized current code is not overridden by history.
        return "DESCONHECIDA"

    latest = history[-1] if history else {}
    latest_code = latest.get("codigo_situacao")
    latest_description = clean_text(latest.get("descricao_situacao"))
    if latest_description:
        return _classify_status_text(latest_description)
    if latest_code in OFFICIAL_SITUATION_CODES:
        return {
            1140: "TRANSFORMADA_EM_NORMA",
            924: "PRONTA_PARA_PAUTA",
            926: "AGUARDANDO_SENADO",
        }[latest_code]
    latest_event = clean_text(latest.get("descricao_tramitacao"))
    if latest_event:
        return _classify_status_text(latest_event)
    return _classify_status_text(latest.get("despacho"))


def transform_record(raw: dict[str, Any]) -> dict[str, Any]:
    detail = raw.get("proposicao", {}).get("dados", raw.get("proposicao", {}))
    authors = raw.get("autores", {}).get("dados", raw.get("autores", [])) or []
    trams = valid_tramitacoes(
        raw.get("tramitacoes", {}).get("dados", raw.get("tramitacoes", [])) or []
    )
    status = detail.get("statusProposicao") or {}
    code = status.get("codSituacao")
    current_description = clean_text(status.get("descricaoSituacao"))
    internal_status = classify(code, current_description, trams)
    if internal_status == "TRANSFORMADA_EM_NORMA":
        # Check the current status first, then the most recent tramitation.
        # Do not infer the enacted law from unrelated legal references in the
        # older history or from proposals that have not become norms.
        law = extract_enacted_law(
            [status.get("despacho")]
            + [t.get("despacho") for t in reversed(trams)]
        )
    else:
        law = {
            "lei_numero": None,
            "lei_tipo": None,
            "lei_data_publicacao": None,
        }
    normalized = {
        "id_projeto": int(detail["id"]),
        "sigla_tipo": clean_text(detail.get("siglaTipo")) or "NAO_INFORMADO",
        "numero": clean_text(detail.get("numero")) or "NAO_INFORMADO",
        "ano": int(detail["ano"]),
        "ementa": clean_text(detail.get("ementa")),
        "data_apresentacao": iso_date(detail.get("dataApresentacao")),
        "uri_api": clean_text(detail.get("uri_api") or detail.get("uri")),
        "url_inteiro_teor": clean_text(detail.get("urlInteiroTeor")),
        "codigo_situacao_api": code,
        "descricao_situacao_api": current_description,
        "status_interno": internal_status,
        "lei_numero": law["lei_numero"],
        "lei_tipo": law["lei_tipo"],
        "lei_data_publicacao": law["lei_data_publicacao"],
        "lei_inicio_vigencia": None,
        "situacao_juridica": None,
        "lei_fonte_publicacao": None,
        "vigencia_verificada": False,
        "fonte_vigencia": None,
        "vigencia_evidencia": None,
        "vigencia_verificada_em": None,
        "autores": [],
        "tramitacoes": trams,
    }
    for author in authors:
        uri = clean_text(author.get("uri"))
        id_match = re.search(r"/(\d+)$", uri or "")
        if not id_match:
            continue
        normalized["autores"].append(
            {
                "id_autor": int(id_match.group(1)),
                "nome": clean_text(author.get("nome")) or "NAO_INFORMADO",
                "tipo": clean_text(author.get("tipo")),
                "uri_api": uri,
                "ordem_assinatura": author.get("ordemAssinatura"),
                "proponente": bool(author.get("proponente", False)),
            }
        )
    normalized["ultima_tramitacao"] = trams[-1] if trams else None
    canonical = json.dumps(
        normalized,
        ensure_ascii=False,
        sort_keys=True,
        default=str,
        separators=(",", ":"),
    )
    normalized["registro_hash"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return normalized


def transform_payload(payload: dict[str, Any]) -> dict[str, Any]:
    records = [transform_record(row) for row in payload.get("registros", [])]
    return {
        "transformado_em": datetime.now(timezone.utc).isoformat(),
        "registros": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="etl/data/raw/extraction.json")
    parser.add_argument("--output", default="etl/data/transformed.json")
    args = parser.parse_args()
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    result = transform_payload(payload)
    Path(args.output).write_text(
        json.dumps(result, ensure_ascii=False, indent=2, default=str), encoding="utf-8"
    )
    print(f"Transformados: {len(result['registros'])}")


if __name__ == "__main__":
    main()
