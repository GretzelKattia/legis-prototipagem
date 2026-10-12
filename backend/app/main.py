from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import get_settings
from .api.routes import router

app = FastAPI(
    title=get_settings().app_name,
    version="4.0.0",
    description="API local do LEGIS sobre dados tratados pelo ETL",
)
settings = get_settings()
configured_origins = [
    origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()
]
allowed_origins = configured_origins or (
    [
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8000",
    ]
    if settings.environment in {"development", "test"}
    else []
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
app.include_router(router)
