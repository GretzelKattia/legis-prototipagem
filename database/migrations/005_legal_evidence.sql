-- LEGIS | Migration 005 — dados jurídicos e evidência verificável
USE legis;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='lei_inicio_vigencia') = 0,
  'ALTER TABLE projeto_lei ADD COLUMN lei_inicio_vigencia DATE NULL AFTER lei_data_publicacao', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='situacao_juridica') = 0,
  'ALTER TABLE projeto_lei ADD COLUMN situacao_juridica VARCHAR(40) NULL AFTER lei_inicio_vigencia', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='lei_fonte_publicacao') = 0,
  'ALTER TABLE projeto_lei ADD COLUMN lei_fonte_publicacao VARCHAR(500) NULL AFTER situacao_juridica', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='vigencia_evidencia') = 0,
  'ALTER TABLE projeto_lei ADD COLUMN vigencia_evidencia TEXT NULL AFTER fonte_vigencia', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='projeto_lei' AND COLUMN_NAME='vigencia_verificada_em') = 0,
  'ALTER TABLE projeto_lei ADD COLUMN vigencia_verificada_em DATETIME NULL AFTER vigencia_evidencia', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS verificacao_vigencia (
    id_verificacao BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_projeto BIGINT UNSIGNED NOT NULL,
    situacao_juridica VARCHAR(40) NOT NULL,
    lei_data_publicacao DATE NULL,
    lei_inicio_vigencia DATE NULL,
    fonte_url VARCHAR(1000) NOT NULL,
    evidencia_texto TEXT NOT NULL,
    revisor VARCHAR(120) NOT NULL,
    resposta_http SMALLINT UNSIGNED NOT NULL,
    conteudo_sha256 CHAR(64) NOT NULL,
    verificada_em DATETIME NOT NULL,
    PRIMARY KEY (id_verificacao),
    CONSTRAINT fk_verificacao_vigencia_projeto FOREIGN KEY (id_projeto)
      REFERENCES projeto_lei (id_projeto) ON DELETE CASCADE,
    INDEX idx_verificacao_vigencia_projeto_data (id_projeto, verificada_em)
) ENGINE=InnoDB;

SET @ddl := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='verificacao_vigencia' AND COLUMN_NAME='revisor') = 0,
  'ALTER TABLE verificacao_vigencia ADD COLUMN revisor VARCHAR(120) NOT NULL DEFAULT ''revisao-legada'' AFTER evidencia_texto', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;
