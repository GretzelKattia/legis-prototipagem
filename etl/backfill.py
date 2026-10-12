"""Backfill histórico das proposições convertidas em norma.

A execução é explícita, por faixa de anos, e deixa cada ano registrado no
etl_execucoes. Coletas limitadas por max_pages ficam marcadas como parciais.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

from .pipeline import run

TYPES = ("PL", "PLP", "PEC")
NORM_STATUS = ["TRANSFORMADA_EM_NORMA"]


def backfill(config_path: str, start_year: int, end_year: int) -> list[dict]:
    current_year = datetime.now(timezone.utc).year
    if start_year < 1900 or end_year > current_year or start_year > end_year:
        raise ValueError("Informe faixa válida: 1900 <= ano inicial <= final <= ano atual")
    results = []
    for year in range(start_year, end_year + 1):
        profiles = [{"siglaTipo": kind, "historico_ano": year} for kind in TYPES]
        result = run(
            config_path,
            filters_override=profiles,
            included_statuses_override=NORM_STATUS,
            persist_statuses_override=NORM_STATUS,
        )
        results.append({"ano": year, **result})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="etl/config.json")
    parser.add_argument("--from-year", type=int, required=True)
    parser.add_argument("--to-year", type=int, required=True)
    args = parser.parse_args()
    results = backfill(args.config, args.from_year, args.to_year)
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 2 if any(row["coleta_parcial"] for row in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
