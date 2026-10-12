from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "LEGIS API"
    environment: str = "development"
    database_url: str = ""
    admin_token: str = ""
    default_user_id: int = 1
    etl_config_path: str = "etl/config.json"
    cors_origins: str = ""
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
