

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

O ETL precisa do schema e da tabela de controle de execuções no MySQL. No MySQL Workbench, abra e execute, na ordem, cada migration abaixo a partir da raiz do repositório:

1. `database/migrations/001_create_schema.sql`
2. `database/migrations/002_add_indexes.sql`
3. `database/migrations/003_add_etl_metadata.sql`
4. `database/migrations/004_tramitacao_unique_nonnull.sql`
5. `database/migrations/005_legal_evidence.sql`

As migrations criam o banco `legis` e as tabelas necessárias. *(Opcional, mas recomendado)* Depois de executá-las, insira um usuário administrador padrão para habilitar a funcionalidade de "Favoritar" projetos de lei no Frontend:

```sql
INSERT INTO usuario (id_usuario, nome, email, senha_hash, criado_em)
VALUES (1, 'Administrador', 'admin@tcc.local', 'senha123', NOW());

```

---

### Passo 2: Extração de Dados (Pipeline ETL)

O robô ETL é responsável por buscar os dados oficiais na API da Câmara dos Deputados, transformar e carregar no banco de dados local.

1. Execute os comandos a partir da raiz do repositório. Crie o ambiente virtual **uma única vez**; se a pasta `.venv` já existir, não execute `venv` novamente.

No **Git Bash**:

```bash
python -m venv .venv
./.venv/Scripts/python.exe -m pip install --upgrade pip
./.venv/Scripts/python.exe -m pip install -r backend/requirements.txt
./.venv/Scripts/python.exe -c "import requests, mysql.connector; print('Dependências OK')"
```

No **PowerShell**, os comandos equivalentes são:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
.\.venv\Scripts\python.exe -c "import requests, mysql.connector; print('Dependências OK')"
```

No **Linux/macOS**:

```bash
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install -r backend/requirements.txt
./.venv/bin/python -c "import requests, mysql.connector; print('Dependências OK')"
```

Use apenas os comandos do terminal que está aberto. Em Git Bash, use `/` nos caminhos; comandos PowerShell como `.\.venv\Scripts\Activate.ps1` não são comandos Bash. Os exemplos chamam diretamente o Python da `.venv`, então não é necessário ativá-la. Se ela já existir, pule a linha `python -m venv .venv`.

2. **Modo Expresso (Recomendado para Testes):** Para evitar que o robô baixe o histórico de anos inteiros, configure o arquivo `etl/config.json` limitando as páginas e o tempo (ex: `"max_pages": 1`, `"periodo_recente_meses": 1`).
3. Com o terminal ainda na raiz do repositório, execute o pipeline:

Git Bash:

```bash
./.venv/Scripts/python.exe -m etl.pipeline
```

PowerShell:

```powershell
.\.venv\Scripts\python.exe -m etl.pipeline
```

Linux/macOS:

```bash
./.venv/bin/python -m etl.pipeline
```

Aguarde a finalização. O terminal exibirá um resumo JSON contendo o total de registros extraídos, transformados e carregados. A execução normal requer conexão com o MySQL, schema criado e credenciais válidas. Para executar a extração e transformação sem gravar no MySQL, acrescente `--skip-load` ao comando do seu terminal; esse modo ainda precisa de acesso à internet para consultar a API da Câmara.

---

### Passo 3: Inicialização do Backend (FastAPI)

A API serve os dados do MySQL para a aplicação Flutter, aplicando regras de negócio e filtros de busca.

1. Com o terminal na raiz do repositório, inicie o servidor local na porta padrão (8000):

**Git Bash:**

```bash
DATABASE_URL="mysql+mysqlconnector://root:root@localhost:3306/legis" uvicorn app.main:app --app-dir backend --reload --port 8000


PowerShell:

```powershell
$env:DATABASE_URL="mysql+mysqlconnector://root:root@localhost:3306/legis"; .\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload --port 8000
```

Linux/macOS:

```bash
DATABASE_URL="mysql+mysqlconnector://root:root@localhost:3306/legis" ./.venv/bin/python -m uvicorn app.main:app --app-dir backend --reload --port 8000
```

2. A documentação interativa da API (Swagger) estará disponível em: `http://localhost:8000/docs`.


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