-- LEGIS | Migration 003 — metadados do ETL
USE legis;

-- Adiciona o hash sem falhar caso a migration já tenha sido aplicada.
SET @column_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projeto_lei' AND COLUMN_NAME = 'registro_hash'
);
SET @sql := IF(@column_exists = 0,
    'ALTER TABLE projeto_lei ADD COLUMN registro_hash CHAR(64) NULL AFTER fonte_vigencia',
    'SELECT 1');
PREPARE add_hash FROM @sql;
EXECUTE add_hash;
DEALLOCATE PREPARE add_hash;

CREATE TABLE IF NOT EXISTS etl_execucoes (
    id_execucao CHAR(36) NOT NULL,
    iniciado_em DATETIME NOT NULL,
    finalizado_em DATETIME NULL,
    status VARCHAR(20) NOT NULL,
    filtros_json JSON NULL,
    paginas INT NULL,
    registros_extraidos INT NOT NULL DEFAULT 0,
    registros_transformados INT NOT NULL DEFAULT 0,
    proposicoes_processadas INT NOT NULL DEFAULT 0,
    autores_processados INT NOT NULL DEFAULT 0,
    tramitacoes_processadas INT NOT NULL DEFAULT 0,
    mensagem_erro TEXT NULL,
    coleta_parcial BOOLEAN NOT NULL DEFAULT FALSE,
    avisos_json JSON NULL,
    PRIMARY KEY (id_execucao),
    INDEX idx_etl_execucoes_status_data (status, iniciado_em)
) ENGINE=InnoDB;

SET @partial_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'etl_execucoes' AND COLUMN_NAME = 'coleta_parcial'
);
SET @sql := IF(@partial_exists = 0,
    'ALTER TABLE etl_execucoes ADD COLUMN coleta_parcial BOOLEAN NOT NULL DEFAULT FALSE AFTER mensagem_erro',
    'SELECT 1');
PREPARE add_partial FROM @sql;
EXECUTE add_partial;
DEALLOCATE PREPARE add_partial;

SET @warnings_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'etl_execucoes' AND COLUMN_NAME = 'avisos_json'
);
SET @sql := IF(@warnings_exists = 0,
    'ALTER TABLE etl_execucoes ADD COLUMN avisos_json JSON NULL AFTER coleta_parcial',
    'SELECT 1');
PREPARE add_warnings FROM @sql;
EXECUTE add_warnings;
DEALLOCATE PREPARE add_warnings;
