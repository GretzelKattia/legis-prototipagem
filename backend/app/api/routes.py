import math
from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    Header,
    HTTPException,
    Query,
    status,
)
import requests
from sqlalchemy import select
from sqlalchemy.orm import Session
from ..config import get_settings
from ..db import get_db
from ..models import EtlExecucao, Notificacao, SessaoUsuario, Usuario, VerificacaoVigencia
from ..repositories import FavoritoRepository, ProposicaoRepository
from ..schemas.api import *
from ..services.etl import is_running, run_sync
from ..services.legal_evidence import fetch_verified_evidence
from ..services.presentation import card, tram
from ..services.auth import find_session_user, hash_password, issue_session, verify_password

router = APIRouter()
repo, fav_repo = ProposicaoRepository(), FavoritoRepository()


def pagination(page: int, per_page: int, total: int):
    return PageMeta(
        pagina=page,
        por_pagina=per_page,
        total=total,
        total_paginas=math.ceil(total / per_page) if total else 0,
    )


def get_current_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
    db: Session = Depends(get_db),
):
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
        user, _ = find_session_user(db, token)
        if user:
            return user
    raise HTTPException(401, "Sessão inválida ou expirada", headers={"WWW-Authenticate": "Bearer"})


def get_user_id(
    authorization: str | None = Header(default=None, alias="Authorization"),
    x_user_id: int | None = Header(default=None, alias="X-User-Id"),
    db: Session = Depends(get_db),
):
    # Legacy test-only adapter; client-supplied IDs are never trusted outside tests.
    if get_settings().environment == "test":
        value = get_settings().default_user_id if x_user_id is None else x_user_id
        if value <= 0:
            raise HTTPException(400, "X-User-Id deve ser positivo")
        if db.get(Usuario, value) is None:
            raise HTTPException(404, "Usuário não encontrado")
        return value
    if authorization and authorization.lower().startswith("bearer "):
        user, _ = find_session_user(db, authorization[7:].strip())
        if user:
            return user.id_usuario
    raise HTTPException(401, "Sessão inválida ou expirada", headers={"WWW-Authenticate": "Bearer"})


def _user_out(user: Usuario) -> dict:
    return {"id": user.id_usuario, "nome": user.nome, "email": user.email}


@router.post("/auth/register", response_model=AuthOut, status_code=201)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    if "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        raise HTTPException(422, "E-mail inválido")
    if db.scalar(select(Usuario).where(Usuario.email == email)):
        raise HTTPException(409, "Já existe uma conta com este e-mail")
    user = Usuario(nome=body.nome.strip(), email=email, senha_hash=hash_password(body.senha), preferencias_json=dict(DEFAULT_PREFERENCES))
    db.add(user)
    db.commit()
    db.refresh(user)
    token, expires = issue_session(db, user)
    return {"access_token": token, "expires_at": expires, "usuario": _user_out(user)}


@router.post("/auth/login", response_model=AuthOut)
def login(body: CredentialsIn, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    user = db.scalar(select(Usuario).where(Usuario.email == email))
    if not user or not verify_password(body.senha, user.senha_hash):
        raise HTTPException(401, "E-mail ou senha inválidos")
    token, expires = issue_session(db, user)
    return {"access_token": token, "expires_at": expires, "usuario": _user_out(user)}


@router.get("/auth/me", response_model=UserOut)
def current_profile(user: Usuario = Depends(get_current_user)):
    return _user_out(user)


@router.patch("/auth/me", response_model=UserOut)
def update_profile(body: ProfileIn, user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    if "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        raise HTTPException(422, "E-mail inválido")
    duplicate = db.scalar(select(Usuario).where(Usuario.email == email, Usuario.id_usuario != user.id_usuario))
    if duplicate:
        raise HTTPException(409, "Já existe uma conta com este e-mail")
    user.nome, user.email = body.nome.strip(), email
    db.commit()
    db.refresh(user)
    return _user_out(user)


@router.post("/auth/change-password", status_code=204)
def change_password(
    body: PasswordChangeIn,
    user: Usuario = Depends(get_current_user),
    authorization: str | None = Header(default=None, alias="Authorization"),
    db: Session = Depends(get_db),
):
    if not verify_password(body.senha_atual, user.senha_hash):
        raise HTTPException(400, "Senha atual incorreta")
    user.senha_hash = hash_password(body.nova_senha)
    current_hash = __import__("hashlib").sha256(authorization[7:].strip().encode()).hexdigest()
    db.query(SessaoUsuario).filter(
        SessaoUsuario.id_usuario == user.id_usuario,
        SessaoUsuario.token_hash != current_hash,
    ).delete(synchronize_session=False)
    db.commit()


@router.post("/auth/logout", status_code=204)
def logout(authorization: str | None = Header(default=None, alias="Authorization"), db: Session = Depends(get_db)):
    if authorization and authorization.lower().startswith("bearer "):
        token_hash = __import__("hashlib").sha256(authorization[7:].strip().encode()).hexdigest()
        session = db.get(SessaoUsuario, token_hash)
        if session:
            db.delete(session)
            db.commit()


DEFAULT_PREFERENCES = {
    "pref_novos_projetos": True,
    "pref_atualizacoes": True,
    "pref_votacoes": False,
    "pref_outras": False,
}
PREFERENCE_KEYS = set(DEFAULT_PREFERENCES)
UNSUPPORTED_PREFERENCES = {"pref_votacoes", "pref_outras"}


@router.get("/usuarios/me/preferencias")
def get_preferences(user: Usuario = Depends(get_current_user)):
    saved = user.preferencias_json or {}
    compatible = {key: value for key, value in saved.items() if key in PREFERENCE_KEYS}
    return {"preferencias": {**DEFAULT_PREFERENCES, **compatible}}


@router.patch("/usuarios/me/preferencias")
def patch_preferences(body: PreferencesIn, user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    unknown = set(body.preferencias) - PREFERENCE_KEYS
    if unknown:
        raise HTTPException(422, f"Preferências desconhecidas: {', '.join(sorted(unknown))}")
    values = {
        key: value for key, value in (user.preferencias_json or {}).items()
        if key in PREFERENCE_KEYS
    }
    if any(body.preferencias.get(key) is True for key in UNSUPPORTED_PREFERENCES):
        raise HTTPException(422, "Notificações de votação e comunicados gerais não são fornecidas pelo ETL atual")
    values = {**DEFAULT_PREFERENCES, **values}
    values.update(body.preferencias)
    user.preferencias_json = values
    db.commit()
    return {"preferencias": values}


@router.get("/notificacoes")
def list_notifications(page: int = Query(1, ge=1), per_page: int = Query(20, ge=1, le=100), user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    base = select(Notificacao).where(Notificacao.id_usuario == user.id_usuario)
    total = db.scalar(select(__import__("sqlalchemy").func.count()).select_from(base.subquery())) or 0
    rows = db.scalars(base.order_by(Notificacao.criada_em.desc(), Notificacao.id_notificacao.desc()).offset((page - 1) * per_page).limit(per_page)).all()
    return {"items": [{"id": n.id_notificacao, "proposicao_id": n.id_projeto, "tipo_evento": n.tipo_evento, "titulo": n.titulo, "descricao": n.descricao, "criada_em": n.criada_em, "lida_em": n.lida_em} for n in rows], "meta": pagination(page, per_page, total)}


@router.patch("/notificacoes/{notification_id}/lida", status_code=204)
def mark_notification_read(notification_id: int, user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    item = db.get(Notificacao, notification_id)
    if not item or item.id_usuario != user.id_usuario:
        raise HTTPException(404, "Notificação não encontrada")
    if item.lida_em is None:
        from datetime import datetime
        item.lida_em = datetime.utcnow()
        db.commit()


def require_admin(
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token")
):
    s = get_settings()
    if not s.admin_token:
        raise HTTPException(503, "Segredo administrativo não configurado")
    if s.environment not in {"development", "test"} and x_admin_token != s.admin_token:
        raise HTTPException(403, "Apenas administrador")
    if x_admin_token != s.admin_token:
        raise HTTPException(403, "Token administrativo inválido")


@router.get("/health")
def health(db: Session = Depends(get_db)):
    try:
        db.execute(__import__("sqlalchemy").text("SELECT 1"))
        dialect = db.get_bind().dialect.name
        return {"status": "ok", "banco": "ok", "fonte_dados": f"{dialect}_local"}
    except Exception:
        raise HTTPException(503, "Banco indisponível")


@router.get("/proposicoes", response_model=ProposicaoPage)
def list_props(
    q: str | None = Query(None, max_length=120),
    tipo: str | None = Query(None, pattern=r"^[A-Za-z]{1,20}$"),
    ano: int | None = Query(None, ge=1900, le=2100),
    status_interno: str | None = Query(None, max_length=50, alias="status"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    rows, total = repo.list(db, q, tipo, ano, status_interno, page, per_page)
    return {"items": [card(p) for p in rows], "meta": pagination(page, per_page, total)}


@router.get("/proposicoes/{pid}", response_model=ProposicaoDetail)
def get_prop(pid: int, db: Session = Depends(get_db)):
    p = repo.get(db, pid)
    if not p:
        raise HTTPException(404, "Proposição não encontrada")
    history = repo.tramitacoes(db, pid)
    authors = [
        {
            "id": a.autor.id_autor,
            "nome": a.autor.nome,
            "tipo": a.autor.tipo,
            "proponente": a.proponente,
            "ordem_assinatura": a.ordem_assinatura,
        }
        for a in p.autores
        if a.autor
    ]
    is_enacted_norm = p.status_interno == "TRANSFORMADA_EM_NORMA" and bool(p.lei_numero)
    return {
        **card(p),
        "ementa": p.ementa,
        "data_apresentacao": p.data_apresentacao,
        "lei_numero": p.lei_numero if is_enacted_norm else None,
        "lei_tipo": p.lei_tipo if is_enacted_norm else None,
        "lei_data_publicacao": p.lei_data_publicacao if is_enacted_norm else None,
        "lei_inicio_vigencia": p.lei_inicio_vigencia if is_enacted_norm else None,
        "situacao_juridica": p.situacao_juridica if is_enacted_norm else None,
        "lei_fonte_publicacao": p.lei_fonte_publicacao if is_enacted_norm else None,
        "fonte_vigencia": p.fonte_vigencia if is_enacted_norm else None,
        "vigencia_evidencia": p.vigencia_evidencia if is_enacted_norm else None,
        "vigencia_verificada_em": p.vigencia_verificada_em if is_enacted_norm else None,
        "autores": authors,
        "ultima_tramitacao": tram(history[-1]) if history else None,
    }


@router.get("/proposicoes/{pid}/autores", response_model=list[AutorOut])
def authors(pid: int, db: Session = Depends(get_db)):
    p = repo.get(db, pid)
    if not p:
        raise HTTPException(404, "Proposição não encontrada")
    return [
        {
            "id": a.autor.id_autor,
            "nome": a.autor.nome,
            "tipo": a.autor.tipo,
            "proponente": a.proponente,
            "ordem_assinatura": a.ordem_assinatura,
        }
        for a in p.autores
        if a.autor
    ]


@router.get("/proposicoes/{pid}/tramitacoes", response_model=list[TramitacaoOut])
def tramitacoes(pid: int, db: Session = Depends(get_db)):
    if not repo.get(db, pid):
        raise HTTPException(404, "Proposição não encontrada")
    return [tram(x) for x in repo.tramitacoes(db, pid)]


@router.get("/proposicoes/{pid}/linha-do-tempo", response_model=list[TramitacaoOut])
def timeline(pid: int, db: Session = Depends(get_db)):
    return tramitacoes(pid, db)


@router.post(
    "/proposicoes/{pid}/verificar-vigencia",
    response_model=VigencyReviewOut,
    status_code=201,
)
def verify_legal_status(
    pid: int,
    body: VigencyReviewIn,
    _=Depends(require_admin),
    db: Session = Depends(get_db),
):
    project = repo.get(db, pid)
    if not project:
        raise HTTPException(404, "Proposição não encontrada")
    if project.status_interno != "TRANSFORMADA_EM_NORMA" or not project.lei_numero:
        raise HTTPException(409, "A proposição ainda não foi identificada como norma")
    try:
        evidence = fetch_verified_evidence(
            source_url=body.fonte_url,
            law_number=project.lei_numero,
            legal_state=body.situacao_juridica,
            evidence_excerpt=body.evidencia_texto,
            effective_date=body.lei_inicio_vigencia,
            publication_date=body.lei_data_publicacao,
        )
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    except requests.RequestException as exc:
        raise HTTPException(502, f"Falha ao consultar a fonte oficial: {exc}") from exc

    project.lei_data_publicacao = evidence["lei_data_publicacao"] or project.lei_data_publicacao
    project.lei_inicio_vigencia = evidence["lei_inicio_vigencia"]
    project.situacao_juridica = evidence["situacao_juridica"]
    project.lei_fonte_publicacao = evidence["fonte_url"]
    project.vigencia_verificada = evidence["situacao_juridica"] == "VIGENTE"
    project.fonte_vigencia = evidence["fonte_url"]
    project.vigencia_evidencia = evidence["evidencia_texto"]
    project.vigencia_verificada_em = evidence["verificada_em"]
    verification = VerificacaoVigencia(
        id_projeto=project.id_projeto,
        revisor=body.revisor.strip(),
        **evidence,
    )
    db.add(verification)
    db.commit()
    db.refresh(verification)
    return verification


@router.get("/favoritos", response_model=FavoritePage)
def favorites(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    uid: int = Depends(get_user_id),
    db: Session = Depends(get_db),
):
    rows, total = repo.favoritos(db, uid, page, per_page)
    return {"items": [card(p) for p in rows], "meta": pagination(page, per_page, total)}


@router.post("/favoritos", response_model=FavoriteOut, status_code=201)
def add_favorite(
    body: FavoriteIn, uid: int = Depends(get_user_id), db: Session = Depends(get_db)
):
    if not repo.get(db, body.proposicao_id):
        raise HTTPException(404, "Proposição não encontrada")
    item = fav_repo.add(db, uid, body.proposicao_id)
    return {"proposicao_id": item.id_projeto, "criado_em": item.criado_em}


@router.delete("/favoritos/{pid}", status_code=204)
def remove_favorite(
    pid: int, uid: int = Depends(get_user_id), db: Session = Depends(get_db)
):
    if not fav_repo.delete(db, uid, pid):
        raise HTTPException(404, "Favorito não encontrado")


@router.post("/etl/sincronizar", response_model=SyncAccepted, status_code=202)
def sync(background_tasks: BackgroundTasks, _=Depends(require_admin)):
    if is_running():
        raise HTTPException(409, "Já existe uma sincronização em execução")
    background_tasks.add_task(run_sync)
    return {"status": "aceita", "mensagem": "Sincronização iniciada em segundo plano"}


@router.get("/etl/status", response_model=EtlStatusOut)
def etl_status(db: Session = Depends(get_db)):
    execution = db.scalar(
        select(EtlExecucao).order_by(EtlExecucao.iniciado_em.desc()).limit(1)
    )
    if not execution:
        return {"status": "SEM_EXECUCAO"}
    return execution
