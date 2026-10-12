-- LEGIS | Migration 002
-- Os quatro índices exigidos já são declarados na migration 001 para permitir
-- execução limpa. Este arquivo é mantido como ponto de evolução da migration.
-- A consulta abaixo pode ser usada para auditoria:
USE legis;

SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'projeto_lei'
  AND INDEX_NAME IN (
      'idx_projeto_sigla_tipo',
      'idx_projeto_ano',
      'idx_projeto_status_interno',
      'idx_projeto_data_apresentacao'
  )
ORDER BY INDEX_NAME, SEQ_IN_INDEX;
