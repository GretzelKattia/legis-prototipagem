from datetime import datetime, timezone
from sqlalchemy import select
from sqlalchemy.orm import Session
from ..models import Favorito, ProjetoLei


class FavoritoRepository:
    def add(self, db: Session, uid: int, pid: int):
        item = db.scalar(
            select(Favorito).where(
                Favorito.id_usuario == uid, Favorito.id_projeto == pid
            )
        )
        if not item:
            item = Favorito(
                id_usuario=uid,
                id_projeto=pid,
                criado_em=datetime.now(timezone.utc),
            )
            db.add(item)
            db.commit()
            db.refresh(item)
        return item

    def delete(self, db: Session, uid: int, pid: int):
        item = db.scalar(
            select(Favorito).where(
                Favorito.id_usuario == uid, Favorito.id_projeto == pid
            )
        )
        if item:
            db.delete(item)
            db.commit()
        return item is not None
