"""Autenticação local por senha com PBKDF2 e tokens opacos revogáveis."""
from __future__ import annotations
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta
from sqlalchemy import select
from sqlalchemy.orm import Session
from ..models import SessaoUsuario, Usuario

ITERATIONS = 600_000
SESSION_DAYS = 30

def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    derived = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
    return f"pbkdf2_sha256${ITERATIONS}${salt.hex()}${derived.hex()}"

def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, iterations, salt_hex, expected = encoded.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), bytes.fromhex(salt_hex), int(iterations)).hex()
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False

def issue_session(db: Session, user: Usuario) -> tuple[str, datetime]:
    token = secrets.token_urlsafe(48)
    expires = datetime.utcnow() + timedelta(days=SESSION_DAYS)
    db.add(SessaoUsuario(token_hash=hashlib.sha256(token.encode()).hexdigest(), id_usuario=user.id_usuario, expira_em=expires))
    db.commit()
    return token, expires

def find_session_user(db: Session, token: str) -> tuple[Usuario | None, str]:
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    session = db.get(SessaoUsuario, token_hash)
    if not session:
        return None, token_hash
    if session.expira_em <= datetime.utcnow():
        db.delete(session)
        db.commit()
        return None, token_hash
    return db.get(Usuario, session.id_usuario), token_hash
