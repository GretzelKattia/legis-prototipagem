-- LEGIS | Migration 001 — schema revisado
-- MySQL 8.0+
-- Compatível com: API Câmara -> ETL Python -> MySQL -> FastAPI

CREATE DATABASE IF NOT EXISTS legis
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE legis;

CREATE TABLE IF NOT EXISTS usuario (
    id_usuario BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    tutorial_concluido BOOLEAN NOT NULL DEFAULT FALSE,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_email UNIQUE (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS projeto_lei (
    -- O ID da Câmara é usado como chave primária para facilitar o ETL idempotente.
    id_projeto BIGINT UNSIGNED NOT NULL,
    sigla_tipo VARCHAR(20) NOT NULL,
    numero VARCHAR(30) NOT NULL,
    ano SMALLINT UNSIGNED NOT NULL,
    ementa TEXT NULL,
    data_apresentacao DATE NULL,
    uri_api VARCHAR(255) NOT NULL,
    url_inteiro_teor VARCHAR(500) NULL,
    codigo_situacao_api INT NULL,
    descricao_situacao_api VARCHAR(200) NULL,
    status_interno VARCHAR(50) NOT NULL,
    lei_numero VARCHAR(30) NULL,
    lei_tipo VARCHAR(50) NULL,
    lei_data_publicacao DATE NULL,
    vigencia_verificada BOOLEAN NOT NULL DEFAULT FALSE,
    fonte_vigencia VARCHAR(500) NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_projeto),
    CONSTRAINT uq_projeto_uri_api UNIQUE (uri_api),
    CONSTRAINT uq_projeto_identidade UNIQUE (sigla_tipo, numero, ano),
    -- Os valores são controlados pelo ETL/FastAPI para permitir novas categorias.
    INDEX idx_projeto_sigla_tipo (sigla_tipo),
    INDEX idx_projeto_ano (ano),
    INDEX idx_projeto_status_interno (status_interno),
    INDEX idx_projeto_data_apresentacao (data_apresentacao)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS autor (
    -- ID oficial do autor na API. Se o ETL precisar de ID interno separado,
    -- criar uma coluna id_autor_interno em uma migration futura.
    id_autor BIGINT UNSIGNED NOT NULL,
    nome VARCHAR(150) NOT NULL,
    tipo VARCHAR(50) NULL,
    uri_api VARCHAR(255) NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_autor),
    CONSTRAINT uq_autor_uri_api UNIQUE (uri_api)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS projeto_autor (
    id_projeto BIGINT UNSIGNED NOT NULL,
    id_autor BIGINT UNSIGNED NOT NULL,
    ordem_assinatura SMALLINT UNSIGNED NULL,
    proponente BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_projeto, id_autor),
    CONSTRAINT fk_projeto_autor_projeto FOREIGN KEY (id_projeto)
        REFERENCES projeto_lei (id_projeto) ON DELETE CASCADE,
    CONSTRAINT fk_projeto_autor_autor FOREIGN KEY (id_autor)
        REFERENCES autor (id_autor) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tramitacao (
    id_tramitacao BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_projeto BIGINT UNSIGNED NOT NULL,
    sequencia INT NOT NULL,
    data_hora DATETIME NULL,
    sigla_orgao VARCHAR(30) NULL,
    uri_orgao VARCHAR(255) NULL,
    regime VARCHAR(150) NULL,
    codigo_tipo_tramitacao INT NULL,
    codigo_situacao INT NULL,
    descricao_situacao VARCHAR(200) NULL,
    descricao_tramitacao TEXT NULL,
    despacho TEXT NULL,
    uri_ultimo_relator VARCHAR(255) NULL,
    url VARCHAR(500) NULL,
    ambito VARCHAR(50) NULL,
    apreciacao VARCHAR(255) NULL,
    coletado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_tramitacao),
    -- A sequência da Câmara é obrigatória e única dentro de cada proposição.
    -- Não usar data_hora/sigla_orgao: ambos aceitam NULL no MySQL.
    CONSTRAINT uq_tramitacao_evento UNIQUE (id_projeto, sequencia),
    CONSTRAINT fk_tramitacao_projeto FOREIGN KEY (id_projeto)
        REFERENCES projeto_lei (id_projeto) ON DELETE CASCADE,
    INDEX idx_tramitacao_projeto_data (id_projeto, data_hora),
    INDEX idx_tramitacao_situacao (codigo_situacao),
    INDEX idx_tramitacao_sequencia (id_projeto, sequencia)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS favorito (
    id_usuario BIGINT UNSIGNED NOT NULL,
    id_projeto BIGINT UNSIGNED NOT NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_projeto),
    CONSTRAINT fk_favorito_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_favorito_projeto FOREIGN KEY (id_projeto)
        REFERENCES projeto_lei (id_projeto) ON DELETE CASCADE,
    INDEX idx_favorito_projeto (id_projeto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notificacao (
    id_notificacao BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_usuario BIGINT UNSIGNED NOT NULL,
    id_projeto BIGINT UNSIGNED NOT NULL,
    id_tramitacao BIGINT UNSIGNED NULL,
    tipo_evento VARCHAR(50) NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    descricao TEXT NULL,
    criada_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lida_em DATETIME NULL,
    enviada_em DATETIME NULL,
    status_envio VARCHAR(30) NOT NULL DEFAULT 'PENDENTE',
    PRIMARY KEY (id_notificacao),
    CONSTRAINT fk_notificacao_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_notificacao_projeto FOREIGN KEY (id_projeto)
        REFERENCES projeto_lei (id_projeto) ON DELETE CASCADE,
    CONSTRAINT fk_notificacao_tramitacao FOREIGN KEY (id_tramitacao)
        REFERENCES tramitacao (id_tramitacao) ON DELETE SET NULL,
    INDEX idx_notificacao_usuario_lida (id_usuario, lida_em),
    INDEX idx_notificacao_projeto (id_projeto),
    INDEX idx_notificacao_status_envio (status_envio)
) ENGINE=InnoDB;
