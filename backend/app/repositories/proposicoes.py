from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, joinedload
from ..models import Autor, Favorito, ProjetoAutor, ProjetoLei, Tramitacao


class ProposicaoRepository:
    def list(
        self, db: Session, q=None, tipo=None, ano=None, status=None, page=1, per_page=20
    ):
        stmt = select(ProjetoLei)
        if q:
            stmt = stmt.where(
                or_(ProjetoLei.ementa.ilike(f"%{q}%"), ProjetoLei.numero == q)
            )
        if tipo:
            stmt = stmt.where(ProjetoLei.sigla_tipo == tipo)
        if ano:
            stmt = stmt.where(ProjetoLei.ano == ano)
        if status == "VIGENCIA_VERIFICADA":
            stmt = stmt.where(
                ProjetoLei.status_interno == "TRANSFORMADA_EM_NORMA",
                ProjetoLei.lei_numero.is_not(None),
                ProjetoLei.vigencia_verificada.is_(True),
                ProjetoLei.situacao_juridica == "VIGENTE",
            )
        elif status:
            stmt = stmt.where(ProjetoLei.status_interno == status)
        total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        rows = db.scalars(
            stmt.order_by(ProjetoLei.atualizado_em.desc(), ProjetoLei.id_projeto.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
        ).all()
        return rows, total

    def get(self, db, pid):
        return db.scalar(
            select(ProjetoLei)
            .options(joinedload(ProjetoLei.autores).joinedload(ProjetoAutor.autor))
            .where(ProjetoLei.id_projeto == pid)
        )

    def tramitacoes(self, db, pid):
        return db.scalars(
            select(Tramitacao)
            .where(Tramitacao.id_projeto == pid)
            .order_by(Tramitacao.sequencia.asc())
        ).all()

    def favoritos(self, db, uid, page, per_page):
        base = (
            select(ProjetoLei)
            .join(Favorito, Favorito.id_projeto == ProjetoLei.id_projeto)
            .where(Favorito.id_usuario == uid)
        )
        total = db.scalar(select(func.count()).select_from(base.subquery())) or 0
        rows = db.scalars(
            base.order_by(Favorito.criado_em.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
        ).all()
        return rows, total
