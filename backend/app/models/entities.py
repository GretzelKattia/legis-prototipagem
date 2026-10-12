from datetime import date, datetime, timezone
from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects import mysql
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..db import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


UnsignedBigInteger = BigInteger().with_variant(Integer, "sqlite").with_variant(
    mysql.BIGINT(unsigned=True), "mysql"
)


class Usuario(Base):
    __tablename__ = "usuario"
    id_usuario: Mapped[int] = mapped_column(UnsignedBigInteger, primary_key=True)
    nome: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(255), unique=True)
    senha_hash: Mapped[str] = mapped_column(String(255), default="local")
    tutorial_concluido: Mapped[bool] = mapped_column(Boolean, default=False)
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )


class ProjetoLei(Base):
    __tablename__ = "projeto_lei"
    id_projeto: Mapped[int] = mapped_column(UnsignedBigInteger, primary_key=True)
    sigla_tipo: Mapped[str] = mapped_column(String(20))
    numero: Mapped[str] = mapped_column(String(30))
    ano: Mapped[int] = mapped_column(SmallInteger)
    ementa: Mapped[str | None] = mapped_column(Text)
    data_apresentacao: Mapped[date | None] = mapped_column(Date)
    uri_api: Mapped[str] = mapped_column(String(255), unique=True)
    url_inteiro_teor: Mapped[str | None] = mapped_column(String(500))
    codigo_situacao_api: Mapped[int | None] = mapped_column(Integer)
    descricao_situacao_api: Mapped[str | None] = mapped_column(String(200))
    status_interno: Mapped[str] = mapped_column(String(50))
    lei_numero: Mapped[str | None] = mapped_column(String(30))
    lei_tipo: Mapped[str | None] = mapped_column(String(50))
    lei_data_publicacao: Mapped[date | None] = mapped_column(Date)
    lei_inicio_vigencia: Mapped[date | None] = mapped_column(Date)
    situacao_juridica: Mapped[str | None] = mapped_column(String(40))
    lei_fonte_publicacao: Mapped[str | None] = mapped_column(String(500))
    vigencia_verificada: Mapped[bool] = mapped_column(Boolean, default=False)
    fonte_vigencia: Mapped[str | None] = mapped_column(String(500))
    vigencia_evidencia: Mapped[str | None] = mapped_column(Text)
    vigencia_verificada_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    registro_hash: Mapped[str | None] = mapped_column(String(64))
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )
    autores: Mapped[list["ProjetoAutor"]] = relationship(back_populates="projeto")
    tramitacoes: Mapped[list["Tramitacao"]] = relationship(back_populates="projeto")


class Autor(Base):
    __tablename__ = "autor"
    id_autor: Mapped[int] = mapped_column(UnsignedBigInteger, primary_key=True)
    nome: Mapped[str] = mapped_column(String(150))
    tipo: Mapped[str | None] = mapped_column(String(50))
    uri_api: Mapped[str | None] = mapped_column(String(255), unique=True)
    projetos: Mapped[list["ProjetoAutor"]] = relationship(back_populates="autor")


class ProjetoAutor(Base):
    __tablename__ = "projeto_autor"
    id_projeto: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("projeto_lei.id_projeto"), primary_key=True
    )
    id_autor: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("autor.id_autor"), primary_key=True
    )
    ordem_assinatura: Mapped[int | None] = mapped_column(SmallInteger)
    proponente: Mapped[bool] = mapped_column(Boolean, default=False)
    projeto: Mapped[ProjetoLei] = relationship(back_populates="autores")
    autor: Mapped[Autor] = relationship(back_populates="projetos")


class Tramitacao(Base):
    __tablename__ = "tramitacao"
    id_tramitacao: Mapped[int] = mapped_column(
        UnsignedBigInteger, primary_key=True, autoincrement=True
    )
    id_projeto: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("projeto_lei.id_projeto")
    )
    sequencia: Mapped[int] = mapped_column(Integer)
    data_hora: Mapped[datetime | None] = mapped_column(DateTime)
    sigla_orgao: Mapped[str | None] = mapped_column(String(30))
    uri_orgao: Mapped[str | None] = mapped_column(String(255))
    regime: Mapped[str | None] = mapped_column(String(150))
    codigo_tipo_tramitacao: Mapped[int | None] = mapped_column(Integer)
    codigo_situacao: Mapped[int | None] = mapped_column(Integer)
    descricao_situacao: Mapped[str | None] = mapped_column(String(200))
    descricao_tramitacao: Mapped[str | None] = mapped_column(Text)
    despacho: Mapped[str | None] = mapped_column(Text)
    uri_ultimo_relator: Mapped[str | None] = mapped_column(String(255))
    url: Mapped[str | None] = mapped_column(String(500))
    ambito: Mapped[str | None] = mapped_column(String(50))
    apreciacao: Mapped[str | None] = mapped_column(String(255))
    coletado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )
    projeto: Mapped[ProjetoLei] = relationship(back_populates="tramitacoes")
    __table_args__ = (
        UniqueConstraint("id_projeto", "sequencia", name="uq_tramitacao_evento"),
    )


class Favorito(Base):
    __tablename__ = "favorito"
    id_usuario: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("usuario.id_usuario"), primary_key=True
    )
    id_projeto: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("projeto_lei.id_projeto"), primary_key=True
    )
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class EtlExecucao(Base):
    __tablename__ = "etl_execucoes"
    id_execucao: Mapped[str] = mapped_column(String(36), primary_key=True)
    iniciado_em: Mapped[datetime] = mapped_column(DateTime)
    finalizado_em: Mapped[datetime | None] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(20))
    filtros_json: Mapped[dict | None] = mapped_column(JSON)
    paginas: Mapped[int | None] = mapped_column(Integer)
    registros_extraidos: Mapped[int] = mapped_column(Integer, default=0)
    registros_transformados: Mapped[int] = mapped_column(Integer, default=0)
    proposicoes_processadas: Mapped[int] = mapped_column(Integer, default=0)
    autores_processados: Mapped[int] = mapped_column(Integer, default=0)
    tramitacoes_processadas: Mapped[int] = mapped_column(Integer, default=0)
    mensagem_erro: Mapped[str | None] = mapped_column(Text)
    coleta_parcial: Mapped[bool] = mapped_column(Boolean, default=False)
    avisos_json: Mapped[list | None] = mapped_column(JSON)


class VerificacaoVigencia(Base):
    __tablename__ = "verificacao_vigencia"
    id_verificacao: Mapped[int] = mapped_column(UnsignedBigInteger, primary_key=True, autoincrement=True)
    id_projeto: Mapped[int] = mapped_column(
        UnsignedBigInteger, ForeignKey("projeto_lei.id_projeto")
    )
    situacao_juridica: Mapped[str] = mapped_column(String(40))
    lei_data_publicacao: Mapped[date | None] = mapped_column(Date)
    lei_inicio_vigencia: Mapped[date | None] = mapped_column(Date)
    fonte_url: Mapped[str] = mapped_column(String(1000))
    evidencia_texto: Mapped[str] = mapped_column(Text)
    revisor: Mapped[str] = mapped_column(String(120))
    resposta_http: Mapped[int] = mapped_column(Integer)
    conteudo_sha256: Mapped[str] = mapped_column(String(64))
    verificada_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
