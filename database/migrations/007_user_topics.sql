-- LEGIS | Migration 007 — temas acompanhados pelo usuário
-- Aplicar depois das migrations 001–006.
USE legis;

ALTER TABLE usuario
    ADD COLUMN temas_json JSON NULL;
