

#  LEGIS - Monitoramento Legislativo (MVP)

Este repositório contém o Produto Mínimo Viável (MVP) do sistema integrado de monitoramento de projetos de lei da Câmara dos Deputados. O projeto foi desenvolvido como Trabalho de Conclusão de Curso (TCC) e é composto por quatro pilares: um Banco de Dados Relacional, um Pipeline ETL, uma API Backend e uma Aplicação Frontend.

## Arquitetura do Sistema

* **Banco de Dados:** MySQL
* **Engenharia de Dados (ETL):** Python
* **Backend (API REST):** FastAPI (Python)
* **Frontend (Web/Mobile):** Flutter (Dart)

---

##  Como testar o projeto localmente

Siga as instruções abaixo na ordem apresentada para garantir que os dados fluam corretamente da API do Governo até a interface de usuário.

### Pré-requisitos

Certifique-se de ter instalado em sua máquina:

* [MySQL Server & Workbench](https://www.google.com/search?q=https://dev.mysql.com/downloads/)
* [Python 3.10+](https://www.python.org/downloads/)
* [Flutter SDK](https://docs.flutter.dev/get-started/install)

---

### Passo 1: Configuração do Banco de Dados (MySQL)

O sistema requer um banco de dados limpo para receber a carga do ETL.

1. Abra o MySQL Workbench e execute o script de criação do banco:

```sql
CREATE DATABASE legis;
USE legis;

```

2. *(Opcional, mas recomendado)* Insira um usuário administrador padrão para habilitar a funcionalidade de "Favoritar" projetos de lei no Frontend:

```sql
INSERT INTO usuario (id_usuario, nome, email, senha_hash, criado_em)
VALUES (1, 'Administrador', 'admin@tcc.local', 'senha123', NOW());

```

---

### Passo 2: Extração de Dados (Pipeline ETL)

O robô ETL é responsável por buscar os dados oficiais na API da Câmara dos Deputados, transformar e carregar no banco de dados local.

1. Navegue até a pasta do ETL e ative o ambiente virtual:

```bash
# Windows
cd LEGIS
python -m venv .venv
.venv\Scripts\activate

# Linux/Mac
cd LEGIS
python3 -m venv .venv
source .venv/bin/activate

```

2. Instale as dependências:

```bash
pip install -r requirements.txt

```

3. **Modo Expresso (Recomendado para Testes):** Para evitar que o robô baixe o histórico de anos inteiros, configure o arquivo `LEGIS/etl/config.json` limitando as páginas e o tempo (ex: `"max_pages": 1`, `"periodo_recente_meses": 1`).
4. Execute o pipeline:

```bash
python -m etl.pipeline

```

Aguarde a finalização. O terminal exibirá um resumo JSON contendo o total de registros extraídos, transformados e carregados.

---

### Passo 3: Inicialização do Backend (FastAPI)

A API serve os dados do MySQL para a aplicação Flutter, aplicando regras de negócio e filtros de busca.

1. Mantenha o ambiente virtual do Python ativado (ou ative-o na pasta do backend).
2. Instale as dependências da API (caso estejam em um `requirements.txt` separado).
3. Inicie o servidor local na porta padrão (8000):

```bash
uvicorn main:app --reload --port 8000

```

4. A documentação interativa da API (Swagger) estará disponível em: `http://localhost:8000/docs`.


#### Testando a API

A coleção de requisições do Insomnia está disponível na pasta [`docs/insomnia/`](./docs/insomnia/).
Para importar:
1. Abra o Insomnia.
2. Vá em **Preferences** > **Data** > **Import Data** > **From File**.
3. Selecione o arquivo `Insomnia_Legis_API.json`.

---

### Passo 4: Inicialização do Frontend (Flutter)

A interface de usuário permite explorar os projetos de lei, ver detalhes das tramitações e favoritar itens de interesse.

1. Abra um novo terminal e navegue até a pasta do projeto Flutter.
2. Baixe as dependências do Dart:

```bash
flutter pub get

```

3. Execute o aplicativo no modo Web (Chrome) simulando a porta 3000:

```bash
flutter run -d chrome --web-port 3000

```

4. Acesse `http://localhost:3000` no seu navegador.

### Dicas de Uso

* **Status Recentes:** Projetos recém-protocolados na Câmara muitas vezes não possuem status jurídico definido pelo Governo. Na interface, eles são elegantemente identificados pela label **"Fase Inicial"** e suas tramitações iniciais como **"Movimentação Registrada"**.
* **Favoritos:** Para testar a inclusão de favoritos, lembre-se de garantir que o Usuário de ID 1 foi criado no banco de dados (conforme o Passo 1).