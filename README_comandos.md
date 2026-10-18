# LEGIS — passo a passo para executar localmente

Este repositório contém o MVP LEGIS: banco MySQL, ETL Python que consulta a API Dados Abertos da Câmara dos Deputados, API FastAPI e aplicativo Flutter.

O banco local começa sem proposições. As migrations criam apenas o schema; a execução do ETL consulta a fonte oficial e insere/atualiza os registros no MySQL. **Não use seeds de proposições nem dados estáticos para popular o banco.**

## Antes de começar: confira os arquivos do ZIP

O ZIP compartilhado originalmente não continha alguns arquivos de configuração necessários. Antes de seguir, confira se estes arquivos existem:

- `pyproject.toml` na raiz do projeto;
- `etl/config.json`;
- `backend/.env.example`.

O conteúdo necessário para `pyproject.toml` e `etl/config.json` está indicado nas seções abaixo. Se o arquivo `backend/.env.example` não estiver presente, crie-o com o exemplo desta documentação. **Não inclua os arquivos `.env` com valores locais no ZIP.**

O teste `backend/tests/test_mysql_integration.py` da cópia original também depende de seeds estáticos e precisa ser adaptado antes de se considerar a integração MySQL validada. As instruções abaixo não recomendam rodar esses seeds.

## 1. Localização e estrutura

Execute os comandos a partir da pasta raiz extraída do ZIP, chamada `legis-prototipagem-main` (ou o nome dado a ela):

```text
legis-prototipagem-main/
├── README.md
├── pyproject.toml       # configuração do pytest; fica na raiz
├── backend/
├── database/
├── etl/
└── frontend/
```

No Windows, abra o PowerShell e entre na pasta. Exemplo:

```powershell
Set-Location "C:\caminho\para\legis-prototipagem-main"
Get-Location
Get-ChildItem
```

Confirme que a listagem mostra `backend`, `database`, `etl`, `frontend` e `README.md`. Os comandos Python deste README devem ser executados a partir dessa pasta, salvo quando indicado explicitamente.

## 2. Pré-requisitos

- Python 3.11 ou superior;
- MySQL Server 8.0 ou superior;
- acesso à internet para consultar a API da Câmara;
- Flutter SDK somente para executar o aplicativo Flutter.

## 3. Criar o ambiente Python e instalar dependências

Na raiz do projeto, crie um ambiente virtual e instale as dependências. Estes comandos chamam diretamente o Python do ambiente, sem depender de ativação:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
```

As dependências Python estão em `backend/requirements.txt`; não existe um `requirements.txt` na raiz.

## 4. Configurar pytest na raiz

O arquivo `pyproject.toml` deve estar diretamente em `legis-prototipagem-main/pyproject.toml`, no mesmo nível deste README. Crie-o com este conteúdo:

```toml
[tool.pytest.ini_options]
pythonpath = [".", "backend"]
testpaths = ["backend/tests", "etl/tests"]
addopts = "-ra"
```

Recomenda-se manter apenas essa configuração; `pytest.ini` não é necessário. Depois, na raiz, rode:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Os testes que usam mocks exercitam o comportamento do código com respostas simuladas em memória; não carregam essas respostas no banco de desenvolvimento. O resultado do comando informa quantos testes passaram, falharam ou foram ignorados nessa execução.

## 5. Preparar o banco MySQL

Abra o MySQL Workbench, conecte-se ao MySQL local e execute os arquivos abaixo, **na ordem indicada**. A primeira migration cria o banco `legis`; as seguintes criam ou atualizam tabelas e índices.

1. `database/migrations/001_create_schema.sql`
2. `database/migrations/002_add_indexes.sql`
3. `database/migrations/003_add_etl_metadata.sql`
4. `database/migrations/004_tramitacao_unique_nonnull.sql`
5. `database/migrations/005_legal_evidence.sql`

Não execute arquivos `database/seeds/*.sql` para inserir proposições. Os dados legislativos devem vir da sincronização com a API na seção 8.

Crie um usuário MySQL local para a aplicação, usando uma senha própria. Execute como administrador no MySQL Workbench:

```sql
CREATE USER 'legis_app'@'127.0.0.1' IDENTIFIED BY 'DEFINA_UMA_SENHA_LOCAL';
GRANT ALL PRIVILEGES ON legis.* TO 'legis_app'@'127.0.0.1';
FLUSH PRIVILEGES;
```

Se sua instalação exigir a conta como `localhost`, use `localhost` consistentemente no comando e nas variáveis de ambiente.

## 6. Criar e configurar os arquivos locais de ambiente

Crie `backend/.env.example` com este modelo, se o ZIP ainda não o trouxer:

```dotenv
ENVIRONMENT=development
DATABASE_URL=mysql+mysqlconnector://legis_app:COLOQUE_SUA_SENHA@127.0.0.1:3306/legis
ADMIN_TOKEN=GERE_UM_TOKEN_LOCAL
DEFAULT_USER_ID=1
ETL_CONFIG_PATH=etl/config.json
CORS_ORIGINS=http://localhost:3000,http://localhost:5000,http://127.0.0.1:3000
```

Depois, na raiz do projeto, copie o modelo para `.env`:

```powershell
Copy-Item .\backend\.env.example .\.env
```

Edite `.env` e substitua os placeholders pelos valores locais. O backend lê esse arquivo na raiz. Não compartilhe nem versione `.env`; compartilhe somente `.env.example`.

O ETL recebe as credenciais MySQL pelas variáveis `LEGIS_DB_*` configuradas na sessão do terminal, conforme a próxima seção. Não é preciso criar nem executar um script `.sh`.

## 7. Configurar o ETL

O arquivo `etl/config.json` precisa existir e conter JSON válido. Se estiver ausente, crie-o com este conteúdo inicial:

```json
{
  "api": {
    "base_url": "https://dadosabertos.camara.leg.br/api/v2",
    "timeout_seconds": 30,
    "max_retries": 3,
    "backoff_seconds": 1,
    "page_size": 100,
    "max_pages": 20
  },
  "filters": [
    { "siglaTipo": "PL", "periodo_recente_meses": 12 },
    { "siglaTipo": "PLP", "periodo_recente_meses": 12 },
    { "siglaTipo": "PEC", "periodo_recente_meses": 12 },
    { "siglaTipo": "PL", "periodo_tramitacao_meses": 3 },
    { "siglaTipo": "PLP", "periodo_tramitacao_meses": 3 },
    { "siglaTipo": "PEC", "periodo_tramitacao_meses": 3 }
  ],
  "status_internos_incluidos": [
    "APROVADA",
    "TRANSFORMADA_EM_NORMA",
    "EM_TRAMITACAO",
    "PRONTA_PARA_PAUTA",
    "AGUARDANDO_SENADO"
  ],
  "database": {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "legis_app",
    "password": "NAO_USADO_QUANDO_LEGIS_DB_PASSWORD_ESTA_DEFINIDA",
    "database": "legis"
  },
  "paths": {
    "status_log": "etl/data/status.jsonl",
    "raw_output": "etl/data/raw/extraction.json",
    "transformed_output": "etl/data/transformed.json"
  }
}
```

Esse perfil coleta PL, PLP e PEC apresentados nos últimos 12 meses, além de consultar janelas recentes de tramitação para localizar alterações em proposições mais antigas. `max_pages` limita a quantidade de páginas por perfil; se o limite for atingido e a execução for indicada como parcial, não apresente a base como completa.

## 8. Sincronizar os dados oficiais para o MySQL

A sincronização é executada pelo ETL. Ele consulta a API Dados Abertos da Câmara, transforma os resultados e os insere/atualiza no MySQL. Execute em um terminal PowerShell **na raiz do projeto**.

Defina as credenciais na sessão atual do PowerShell — substitua a senha pelo valor local, sem colocá-la no README, no ZIP ou no `config.json`:

```powershell
$env:LEGIS_DB_HOST = "127.0.0.1"
$env:LEGIS_DB_PORT = "3306"
$env:LEGIS_DB_USER = "legis_app"
$env:LEGIS_DB_PASSWORD = "SUA_SENHA_LOCAL"
$env:LEGIS_DB_DATABASE = "legis"
```

Execute o comando direto do ETL, sem `scripts/run_etl.sh`:

```powershell
.\.venv\Scripts\python.exe -m etl.pipeline --config etl/config.json
```

Esse comando executa extração, transformação e carga. Requer conexão de rede com a API e acesso ao MySQL. O backend não sincroniza a Câmara automaticamente apenas por estar aberto. Para atualizar os dados, execute novamente o comando do ETL ou configure um agendamento explícito no sistema operacional.

Se houver falha HTTP, erro de banco ou limite de páginas, consulte a mensagem final e os logs de execução. Não invente nem substitua dados ausentes; uma execução indicada como parcial não representa cobertura completa.

## 9. Iniciar a API FastAPI

Com o banco e o `.env` configurados, abra outro PowerShell na raiz do projeto e rode diretamente:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload --host 127.0.0.1 --port 8000
```

Mantenha o terminal aberto. Endereços locais:

- API: <http://127.0.0.1:8000>
- Swagger: <http://127.0.0.1:8000/docs>
- OpenAPI JSON: <http://127.0.0.1:8000/openapi.json>

## 10. Executar o frontend Flutter

Com a API rodando, abra outro terminal:

```powershell
Set-Location .\frontend
flutter pub get
flutter run -d chrome --web-port 3000
```

O Flutter SDK precisa estar instalado. O app web se conecta ao backend local em `http://localhost:8000`. Em emuladores móveis ou outro dispositivo, `localhost` pode precisar ser substituído pelo endereço acessível do computador que executa o backend.

## 11. Estados legislativos e vigência

A transformação em norma não comprova, por si só, que ela esteja atualmente vigente. Mantenha separados o estado legislativo, os dados de publicação/início de vigência e a evidência jurídica consultada. Só marque `vigencia_verificada` com evidência explícita e verificável em fonte oficial.

## 12. Segurança

`X-User-Id` é apenas um identificador do MVP; não autentica nem comprova a identidade do usuário. Valores menores ou iguais a zero devem ser rejeitados. Antes de produção, implemente autenticação e autorização reais e não confie em um identificador informado livremente pelo cliente.

Não compartilhe `.env`, senhas, tokens ou credenciais. Se um arquivo `.env` com valores preenchidos já foi enviado, trate as credenciais como expostas e troque-as antes de continuar usando-as.

## 13. Limitação conhecida do teste MySQL

O `backend/tests/test_mysql_integration.py` da cópia original ainda espera arquivos de seed e verifica registros estáticos. Como o fluxo desejado não deve inserir proposições por seeds, ajuste esse teste para usar apenas um schema temporário de teste, sem seeds e sem tocar no banco local, antes de considerar a integração MySQL validada. Não aponte testes para um banco com dados que queira preservar.
