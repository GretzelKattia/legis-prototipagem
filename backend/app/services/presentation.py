from ..models import ProjetoLei, Tramitacao

STATUS_LABELS = {
    "APROVADA": "Aprovada",
    "TRANSFORMADA_EM_NORMA": "Transformada em Norma",
    "VIGENCIA_VERIFICADA": "Vigência verificada",
    "EM_TRAMITACAO": "Em tramitação",
    "PRONTA_PARA_PAUTA": "Pronta para pauta",
    "AGUARDANDO_SENADO": "Aguardando Senado",
    "ARQUIVADA": "Arquivada",
    "REJEITADA": "Rejeitada",
    "PREJUDICADA": "Prejudicada",
    "DESCONHECIDA": "Situação não identificada",
}


def title(p: ProjetoLei) -> str | None:
    return p.ementa


def status(p: ProjetoLei) -> dict:
    # A stale review must never make an active/unknown proposal look like a
    # law with verified current vigency. Only expose legal metadata while the
    # current authoritative state still links the proposal to an enacted law.
    is_enacted_norm = p.status_interno == "TRANSFORMADA_EM_NORMA" and bool(p.lei_numero)
    verified = (
        is_enacted_norm
        and bool(p.vigencia_verificada)
        and p.situacao_juridica == "VIGENTE"
    )
    detail = None
    if is_enacted_norm:
        lei_tipo = (p.lei_tipo or "Ordinária").strip()
        if not lei_tipo.lower().startswith("lei "):
            lei_tipo = f"Lei {lei_tipo}"
        detail = f"{lei_tipo} nº {p.lei_numero}"
    code = "VIGENCIA_VERIFICADA" if verified else p.status_interno
    return {
        "codigo": code,
        "rotulo": STATUS_LABELS.get(code, "Status não informado"),
        "detalhe": detail,
        "vigencia_verificada": verified,
        "situacao_juridica": p.situacao_juridica if is_enacted_norm else None,
        "inicio_vigencia": p.lei_inicio_vigencia if is_enacted_norm else None,
        "fonte_vigencia": p.fonte_vigencia if is_enacted_norm else None,
        "verificada_em": p.vigencia_verificada_em if is_enacted_norm else None,
    }


def card(p: ProjetoLei) -> dict:
    return {
        "id": p.id_projeto,
        "titulo": title(p),
        "tipo": p.sigla_tipo,
        "numero": p.numero,
        "ano": p.ano,
        "status": status(p),
        "atualizado_em": p.atualizado_em,
    }


def tram(t: Tramitacao) -> dict:
    return {
        "id": t.id_tramitacao,
        "sequencia": t.sequencia,
        "data_hora": t.data_hora,
        "orgao": t.sigla_orgao,
        "situacao": t.descricao_situacao,
        "descricao": t.descricao_tramitacao,
        "despacho": t.despacho,
        "atualizado_em": t.atualizado_em,
    }
