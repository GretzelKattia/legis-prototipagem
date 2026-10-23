-- LEGIS | Migration 006 — sessões, preferências e deduplicação de notificações
-- Aplicar depois das migrations 001–005. Não armazena tokens de sessão em texto puro.
USE legis;

ALTER TABLE usuario ADD COLUMN preferencias_json JSON NULL;

CREATE TABLE usuario_sessao (
    token_hash CHAR(64) NOT NULL,
    id_usuario BIGINT UNSIGNED NOT NULL,
    criada_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_em DATETIME NOT NULL,
    PRIMARY KEY (token_hash),
    CONSTRAINT fk_sessao_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario) ON DELETE CASCADE,
    INDEX idx_sessao_expira (expira_em),
    INDEX idx_sessao_usuario (id_usuario)
) ENGINE=InnoDB;

-- Uma sincronização repetida da mesma movimentação não duplica a notificação.
CREATE UNIQUE INDEX uq_notificacao_usuario_tramitacao_tipo
    ON notificacao (id_usuario, id_tramitacao, tipo_evento);

-- Notificações sem tramitação (ex.: proposição inserida nesta sincronização).
-- A coluna gerada evita que este índice impeça avisos de tramitações distintas
-- da mesma proposição; esses são deduplicados pelo índice acima, por id_tramitacao.
ALTER TABLE notificacao
    ADD COLUMN projeto_sem_tramitacao BIGINT UNSIGNED
        GENERATED ALWAYS AS (IF(id_tramitacao IS NULL, id_projeto, NULL)) STORED;

CREATE UNIQUE INDEX uq_notificacao_usuario_projeto_tipo
    ON notificacao (id_usuario, projeto_sem_tramitacao, tipo_evento);
