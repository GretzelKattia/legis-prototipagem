-- LEGIS | Migration 004 — chave de tramitação idempotente
-- A sequência oficial é NOT NULL e identifica o evento dentro da proposição.
-- Antes de executar: investigar eventuais duplicatas já existentes; não as apaga.
USE legis;

SELECT id_projeto, sequencia, COUNT(*) AS ocorrencias
FROM tramitacao
GROUP BY id_projeto, sequencia
HAVING COUNT(*) > 1;

SET @old_index_exists := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tramitacao'
      AND INDEX_NAME = 'uq_tramitacao_evento'
);
SET @sql := IF(@old_index_exists > 0,
    'ALTER TABLE tramitacao DROP INDEX uq_tramitacao_evento', 'SELECT 1');
PREPARE drop_old_index FROM @sql;
EXECUTE drop_old_index;
DEALLOCATE PREPARE drop_old_index;

SET @new_index_exists := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tramitacao'
      AND INDEX_NAME = 'uq_tramitacao_evento'
);
SET @sql := IF(@new_index_exists = 0,
    'ALTER TABLE tramitacao ADD CONSTRAINT uq_tramitacao_evento UNIQUE (id_projeto, sequencia)',
    'SELECT 1');
PREPARE add_new_index FROM @sql;
EXECUTE add_new_index;
DEALLOCATE PREPARE add_new_index;
