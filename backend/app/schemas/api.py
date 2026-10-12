from datetime import date, datetime
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict


class StatusOut(BaseModel):
    codigo: str
    rotulo: str
    detalhe: str | None = None
    vigencia_verificada: bool = False
    situacao_juridica: str | None = None
    inicio_vigencia: date | None = None
    fonte_vigencia: str | None = None
    verificada_em: datetime | None = None


class ProposicaoCard(BaseModel):
    id: int
    titulo: str | None
    tipo: str
    numero: str
    ano: int
    status: StatusOut
    atualizado_em: datetime | None


class PageMeta(BaseModel):
    pagina: int
    por_pagina: int
    total: int
    total_paginas: int


class ProposicaoPage(BaseModel):
    items: list[ProposicaoCard]
    meta: PageMeta


class AutorOut(BaseModel):
    id: int
    nome: str
    tipo: str | None = None
    proponente: bool = False
    ordem_assinatura: int | None = None


class TramitacaoOut(BaseModel):
    id: int
    sequencia: int
    data_hora: datetime | None
    orgao: str | None
    situacao: str | None
    descricao: str | None
    despacho: str | None
    atualizado_em: datetime | None


class ProposicaoDetail(ProposicaoCard):
    ementa: str | None
    data_apresentacao: date | None
    lei_numero: str | None
    lei_tipo: str | None
    lei_data_publicacao: date | None
    lei_inicio_vigencia: date | None = None
    situacao_juridica: str | None = None
    lei_fonte_publicacao: str | None = None
    fonte_vigencia: str | None = None
    vigencia_evidencia: str | None = None
    vigencia_verificada_em: datetime | None = None
    autores: list[AutorOut] = []
    ultima_tramitacao: TramitacaoOut | None = None


class FavoriteIn(BaseModel):
    proposicao_id: int = Field(gt=0)


class FavoriteOut(BaseModel):
    proposicao_id: int
    criado_em: datetime


class FavoritePage(BaseModel):
    items: list[ProposicaoCard]
    meta: PageMeta


class SyncAccepted(BaseModel):
    status: str
    mensagem: str


class EtlStatusOut(BaseModel):
    status: str
    iniciado_em: datetime | None = None
    finalizado_em: datetime | None = None
    paginas: int | None = None
    registros_extraidos: int = 0
    registros_transformados: int = 0
    proposicoes_processadas: int = 0
    autores_processados: int = 0
    tramitacoes_processadas: int = 0
    mensagem_erro: str | None = None
    coleta_parcial: bool = False
    avisos_json: list | None = None


class VigencyReviewIn(BaseModel):
    situacao_juridica: Literal[
        "VIGENTE",
        "NAO_CONSTA_REVOGACAO_EXPRESSA",
        "PARCIALMENTE_VIGENTE",
        "REVOGADA",
        "VACATIO_LEGIS",
    ]
    fonte_url: str = Field(min_length=12, max_length=500)
    evidencia_texto: str = Field(min_length=40, max_length=1500)
    revisor: str = Field(min_length=3, max_length=120)
    lei_data_publicacao: date | None = None
    lei_inicio_vigencia: date | None = None


class VigencyReviewOut(BaseModel):
    id_verificacao: int
    id_projeto: int
    situacao_juridica: str
    lei_data_publicacao: date | None
    lei_inicio_vigencia: date | None
    fonte_url: str
    evidencia_texto: str
    revisor: str
    resposta_http: int
    conteudo_sha256: str
    verificada_em: datetime
