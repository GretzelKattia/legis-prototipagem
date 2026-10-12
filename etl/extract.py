"""Extração controlada da API Dados Abertos da Câmara."""

from __future__ import annotations

import argparse
import calendar
import json
import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import requests

LOGGER = logging.getLogger("legis.etl.extract")
RETRYABLE_STATUS = {429, 500, 502, 503, 504}


def expand_filter_profiles(
    filter_profiles: Iterable[dict[str, Any]], today: Any = None
) -> list[dict[str, Any]]:
    """Expande períodos em janelas trimestrais aceitas pelo endpoint da Câmara."""
    end_date = today or datetime.now(timezone.utc).date()
    expanded: list[dict[str, Any]] = []
    for profile in filter_profiles:
        historic_year = profile.get("historico_ano")
        presentation_months = profile.get("periodo_recente_meses")
        tramitation_months = profile.get("periodo_tramitacao_meses")
        if not (historic_year or presentation_months or tramitation_months):
            expanded.append(dict(profile))
            continue
        if historic_year:
            if not isinstance(historic_year, int) or not 1900 <= historic_year <= end_date.year:
                raise ValueError("historico_ano deve ser um ano válido não futuro")
            start_date = end_date.replace(year=historic_year, month=1, day=1)
            end_limit = min(end_date, end_date.replace(year=historic_year, month=12, day=31))
            date_prefix = "dataApresentacao"
        else:
            months = presentation_months or tramitation_months
            if not isinstance(months, int) or months < 1 or months > 12:
                raise ValueError("o período deve ser um inteiro entre 1 e 12 meses")
            month_index = end_date.year * 12 + end_date.month - 1 - months
            year, month0 = divmod(month_index, 12)
            month = month0 + 1
            start_date = end_date.replace(
                year=year,
                month=month,
                day=min(end_date.day, calendar.monthrange(year, month)[1]),
            )
            end_limit = end_date
            date_prefix = "dataApresentacao" if presentation_months else "data"
        cursor = start_date
        while cursor < end_limit:
            month_index = cursor.year * 12 + cursor.month - 1 + 3
            end_year, end_month0 = divmod(month_index, 12)
            end_month = end_month0 + 1
            window_end = cursor.replace(
                year=end_year,
                month=end_month,
                day=min(cursor.day, calendar.monthrange(end_year, end_month)[1]),
            )
            if window_end > end_limit:
                window_end = end_limit
            keys = (
                ("dataApresentacaoInicio", "dataApresentacaoFim")
                if date_prefix == "dataApresentacao"
                else ("dataInicio", "dataFim")
            )
            expanded.append(
                {
                    **{
                        k: v
                        for k, v in profile.items()
                        if k not in (
                            "periodo_recente_meses",
                            "periodo_tramitacao_meses",
                            "historico_ano",
                        )
                    },
                    keys[0]: cursor.isoformat(),
                    keys[1]: window_end.isoformat(),
                }
            )
            cursor = window_end
    return expanded


@dataclass(frozen=True)
class ExtractionConfig:
    base_url: str
    timeout_seconds: float = 20.0
    max_retries: int = 3
    backoff_seconds: float = 0.5
    page_size: int = 100
    max_pages: int = 20

    def __post_init__(self) -> None:
        if not 1 <= self.page_size <= 100:
            raise ValueError("page_size deve estar entre 1 e 100")
        if self.max_pages < 1:
            raise ValueError("max_pages deve ser positivo")
        if self.max_retries < 0:
            raise ValueError("max_retries não pode ser negativo")


class JsonlStatusLog:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event: dict[str, Any]) -> None:
        record = {"timestamp": datetime.now(timezone.utc).isoformat(), **event}
        with self.path.open("a", encoding="utf-8") as file:
            file.write(json.dumps(record, ensure_ascii=False) + "\n")


class CamaraExtractor:
    def __init__(
        self,
        config: ExtractionConfig,
        status_log: JsonlStatusLog,
        session: requests.Session | None = None,
    ) -> None:
        self.config = config
        self.status_log = status_log
        self.session = session or requests.Session()
        self._candidate_ids: set[int] = set()
        self.metrics: dict[str, Any] = {
            "paginas_processadas": 0,
            "candidatos_unicos": 0,
            "registros_extraidos": 0,
            "extracao_completa": False,
            "coleta_parcial": False,
            "avisos": [],
        }

    def request_json(self, path: str, params: dict[str, Any] | None = None) -> Any:
        url = f"{self.config.base_url.rstrip('/')}/{path.lstrip('/')}"
        last_error: Exception | None = None
        for attempt in range(self.config.max_retries + 1):
            try:
                response = self.session.get(
                    url, params=params, timeout=self.config.timeout_seconds
                )
                self.status_log.write(
                    {
                        "event": "http_response",
                        "method": "GET",
                        "url": response.url,
                        "status_http": response.status_code,
                        "attempt": attempt + 1,
                    }
                )
                if (
                    response.status_code in RETRYABLE_STATUS
                    and attempt < self.config.max_retries
                ):
                    time.sleep(self.config.backoff_seconds * (2**attempt))
                    continue
                response.raise_for_status()
                return response.json()
            except requests.HTTPError as exc:
                last_error = exc
                status_http = getattr(exc.response, "status_code", None)
                self.status_log.write(
                    {
                        "event": "http_error",
                        "method": "GET",
                        "url": url,
                        "status_http": status_http,
                        "attempt": attempt + 1,
                        "error": str(exc),
                    }
                )
                if status_http not in RETRYABLE_STATUS or attempt >= self.config.max_retries:
                    raise
                time.sleep(self.config.backoff_seconds * (2**attempt))
                continue
            except (requests.RequestException, ValueError) as exc:
                last_error = exc
                self.status_log.write(
                    {
                        "event": "http_error",
                        "method": "GET",
                        "url": url,
                        "status_http": getattr(
                            getattr(exc, "response", None), "status_code", None
                        ),
                        "attempt": attempt + 1,
                        "error": str(exc),
                    }
                )
                if attempt < self.config.max_retries:
                    time.sleep(self.config.backoff_seconds * (2**attempt))
                    continue
                raise
        raise RuntimeError(f"Falha inesperada em {url}: {last_error}")

    def list_candidates(self, filters: dict[str, Any]) -> list[dict[str, Any]]:
        candidates: list[dict[str, Any]] = []
        for page in range(1, self.config.max_pages + 1):
            params = {
                key: value
                for key, value in filters.items()
                if value not in (None, "", [])
            }
            params.update({"pagina": page, "itens": self.config.page_size})
            payload = self.request_json("proposicoes", params)
            page_items = payload.get("dados", [])
            if not isinstance(page_items, list):
                raise ValueError("Resposta de /proposicoes sem lista dados")
            candidates.extend(page_items)
            for item in page_items:
                if isinstance(item, dict) and item.get("id") is not None:
                    self._candidate_ids.add(int(item["id"]))
            self.metrics["candidatos_unicos"] = len(self._candidate_ids)
            self.metrics["paginas_processadas"] += 1
            self.status_log.write(
                {
                    "event": "page_success",
                    "page": page,
                    "page_items": len(page_items),
                    "filters": filters,
                }
            )
            if len(page_items) < self.config.page_size:
                break
            if page == self.config.max_pages:
                warning = (
                    "Coleta potencialmente incompleta: max_pages foi atingido "
                    "e a última página veio cheia."
                )
                self.metrics["coleta_parcial"] = True
                self.metrics["avisos"].append(warning)
                self.status_log.write(
                    {
                        "event": "collection_truncated",
                        "page": page,
                        "max_pages": self.config.max_pages,
                        "page_items": len(page_items),
                        "filters": filters,
                        "warning": warning,
                    }
                )
        return candidates

    def extract_proposition(self, candidate: dict[str, Any]) -> dict[str, Any]:
        proposition_id = int(candidate["id"])
        return {
            "proposicao": self.request_json(f"proposicoes/{proposition_id}"),
            "autores": self.request_json(f"proposicoes/{proposition_id}/autores"),
            "tramitacoes": self.request_json(
                f"proposicoes/{proposition_id}/tramitacoes"
            ),
        }

    def run(self, filter_profiles: Iterable[dict[str, Any]]) -> dict[str, Any]:
        candidates_by_id: dict[int, dict[str, Any]] = {}
        expanded_profiles = expand_filter_profiles(filter_profiles)
        for filters in expanded_profiles:
            for candidate in self.list_candidates(filters):
                if "id" in candidate:
                    candidates_by_id[int(candidate["id"])] = candidate
        records = []
        for candidate in candidates_by_id.values():
            records.append(self.extract_proposition(candidate))
            self.metrics["registros_extraidos"] = len(records)
        self.metrics["extracao_completa"] = True
        result = {
            "extraido_em": datetime.now(timezone.utc).isoformat(),
            "candidatos": list(candidates_by_id.values()),
            "registros": records,
            **self.metrics,
        }
        self.status_log.write(
            {
                "event": "extraction_success",
                "candidate_count": len(candidates_by_id),
                "record_count": len(records),
                "paginas_processadas": self.metrics["paginas_processadas"],
                "coleta_parcial": self.metrics["coleta_parcial"],
                "avisos": self.metrics["avisos"],
            }
        )
        return result


def load_config(path: str | Path) -> dict[str, Any]:
    with Path(path).open(encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="etl/config.json")
    parser.add_argument("--output", default="etl/data/raw/extraction.json")
    args = parser.parse_args()
    config_data = load_config(args.config)
    etl_config = ExtractionConfig(**config_data["api"])
    status_log = JsonlStatusLog(config_data["paths"]["status_log"])
    extractor = CamaraExtractor(etl_config, status_log)
    result = extractor.run(config_data["filters"])
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    LOGGER.info("Extração concluída: %s registros", len(result["registros"]))


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()
