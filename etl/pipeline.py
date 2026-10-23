"""Orquestrador da execução completa do ETL."""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

if __package__:
    from .extract import (
        CamaraExtractor,
        ExtractionConfig,
        JsonlStatusLog,
        expand_filter_profiles,
        load_config,
    )
    from .load import MySQLLoader, db_config
    from .transform import transform_payload
else:  # execução direta: python etl/pipeline.py
    from extract import (
        CamaraExtractor,
        ExtractionConfig,
        JsonlStatusLog,
        expand_filter_profiles,
        load_config,
    )
    from load import MySQLLoader, db_config
    from transform import transform_payload

LOGGER = logging.getLogger("legis.etl.pipeline")


def run(
    config_path: str,
    skip_load: bool = False,
    *,
    filters_override: list[dict] | None = None,
    included_statuses_override: list[str] | None = None,
    persist_statuses_override: list[str] | None = None,
) -> dict:
    config = load_config(config_path)
    paths = config["paths"]
    status_log = JsonlStatusLog(paths["status_log"])
    extractor = CamaraExtractor(ExtractionConfig(**config["api"]), status_log)
    loader = None if skip_load else MySQLLoader(db_config(config))
    filters = expand_filter_profiles(filters_override or config["filters"])
    execution_id = None
    started = None
    extracted = {}
    transformed = {}
    try:
        # Include the initial database registration in the guarded block too:
        # if MySQL is unavailable, still write a local pipeline_error event.
        if loader:
            execution_id, started = loader.start_execution(filters)
        extracted = extractor.run(filters)
        Path(paths["raw_output"]).parent.mkdir(parents=True, exist_ok=True)
        Path(paths["raw_output"]).write_text(
            json.dumps(extracted, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        transformed = transform_payload(extracted)
        included_statuses = (
            included_statuses_override
            if included_statuses_override is not None
            else config.get("status_internos_incluidos")
        )
        # A lista de estados incluídos controla a apresentação, não a
        # persistência. Estados finais/administrativos podem deixar de aparecer
        # na interface, mas suas mudanças precisam continuar no banco.
        apresentaveis = transformed["registros"]
        if included_statuses is not None:
            apresentaveis = [
                record
                for record in transformed["registros"]
                if record["status_interno"] in included_statuses
            ]
        transformed["registros_apresentaveis"] = len(apresentaveis)
        Path(paths["transformed_output"]).write_text(
            json.dumps(transformed, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )
        result = {
            "extraidos": len(extracted["registros"]),
            "transformados": len(transformed["registros"]),
            "apresentaveis": len(apresentaveis),
            "carga": None,
            "coleta_parcial": extracted.get("coleta_parcial", False),
            "avisos": extracted.get("avisos", []),
        }
        if loader:
            records_to_persist = transformed["registros"]
            if persist_statuses_override is not None:
                records_to_persist = [
                    record
                    for record in transformed["registros"]
                    if record["status_interno"] in persist_statuses_override
                ]
            result["carga"] = loader.load(
                {**transformed, "registros": records_to_persist},
                filters,
                extracted_count=len(extracted["registros"]),
                transformed_count=len(transformed["registros"]),
                execution_id=execution_id,
                started=started,
                pages=extracted.get("paginas_processadas", 0),
                partial=extracted.get("coleta_parcial", False),
                warnings=extracted.get("avisos", []),
            )
        status_log.write({"event": "pipeline_success", **result})
        return result
    except Exception as exc:
        execution_log_error = None
        pages_processed = extracted.get(
            "paginas_processadas", extractor.metrics.get("paginas_processadas", 0)
        )
        extracted_count = len(
            extracted.get("registros", [])
        ) if extracted else extractor.metrics.get("registros_extraidos", 0)
        collection_was_incomplete = (
            not extractor.metrics.get("extracao_completa", False)
            and pages_processed > 0
        )
        partial = bool(
            extracted.get("coleta_parcial", False)
            or extractor.metrics.get("coleta_parcial", False)
            or collection_was_incomplete
        )
        warnings = list(extracted.get("avisos", extractor.metrics.get("avisos", [])))
        if collection_was_incomplete:
            warning = "Extração interrompida antes da conclusão; os dados coletados não representam uma base completa."
            if warning not in warnings:
                warnings.append(warning)
        if loader and execution_id:
            try:
                loader.finish_execution(
                    execution_id,
                    "ERRO",
                    str(exc),
                    pages=pages_processed,
                    extracted=extracted_count,
                    transformed=len(transformed.get("registros", [])),
                    partial=partial,
                    warnings=warnings,
                )
            except Exception as log_exc:
                # Preserve the original pipeline error and make the failure to
                # update MySQL visible in the local status log.
                execution_log_error = str(log_exc)
        event = {
            "event": "pipeline_error",
            "error": str(exc),
            "paginas_processadas": pages_processed,
            "registros_extraidos": extracted_count,
            "candidatos_unicos": extractor.metrics.get("candidatos_unicos", 0),
            "coleta_parcial": partial,
            "avisos": warnings,
        }
        if execution_log_error:
            event["execution_log_error"] = execution_log_error
        status_log.write(event)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="etl/config.json")
    parser.add_argument(
        "--skip-load",
        action="store_true",
        help="Executa extração e transformação sem MySQL",
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    print(json.dumps(run(args.config, args.skip_load), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

