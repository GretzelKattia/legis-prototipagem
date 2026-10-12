"""Valida códigos de situação contra a referência oficial da Câmara."""

from __future__ import annotations

import argparse
import requests

EXPECTED = {
    924: "Pronta para Pauta",
    926: "Aguardando Apreciação pelo Senado Federal",
    1140: "Transformado em Norma Jurídica",
}


def validate(base_url: str, timeout: float = 30.0) -> dict[int, str]:
    response = requests.get(
        f"{base_url.rstrip('/')}/referencias/proposicoes/codSituacao",
        headers={"Accept": "application/json"},
        timeout=timeout,
    )
    response.raise_for_status()
    rows = response.json().get("dados", [])
    official = {int(row["cod"]): row["nome"] for row in rows if row.get("cod")}
    for code, expected in EXPECTED.items():
        actual = official.get(code)
        if actual != expected:
            raise AssertionError(
                f"Código {code}: esperado {expected!r}, recebido {actual!r}"
            )
    return {code: official[code] for code in EXPECTED}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base-url", default="https://dadosabertos.camara.leg.br/api/v2"
    )
    args = parser.parse_args()
    print(validate(args.base_url))


if __name__ == "__main__":
    main()
