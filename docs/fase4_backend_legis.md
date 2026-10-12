# Fase 4 — BACKEND do LEGIS

## 1. Objetivo da fase

A Fase 4 implementa o backend do LEGIS com **FastAPI**, conectado ao **MySQL local** e preparado para ser consumido pelo Flutter, pelo Insomnia e por outras interfaces.

O backend não consulta diretamente a API Dados Abertos durante as chamadas públicas. O fluxo definido para o projeto é:

```text
API Dados Abertos da Câmara
            │
            ▼
          ETL
  extração → transformação → carga
            │
            ▼
       MySQL local
            │
            ▼
         FastAPI
            │
     ┌──────┴──────┐
     ▼             ▼
  Flutter       Insomnia
            │
            ▼
  Favoritos e notificações
```

A API Dados Abertos só é acessada quando a sincronização do ETL é iniciada explicitamente.

---

## 2. Validação realizada

Foi executada a seguinte chamada:

```bash
curl --request GET \
  --url http://127.0.0.1:8000/proposicoes/540979
```

A resposta retornou a proposição `540979`, correspondente ao PL `2913/2021`.

Também foi executada uma consulta diretamente no MySQL:

```sql
SELECT
    id_projeto,
    sigla_tipo,
    numero,
    ano,
    ementa,
    status_interno,
    atualizado_em
FROM projeto_lei
WHERE id_projeto = 540979;
```

Resultado validado:

```text
540979  PL  2913  2021  Cria o Selo Verde Cacau Cabruca.
TRANSFORMADA_EM_NORMA  2026-09-27 23:48:26
```

### Conclusão da validação

A resposta está condizente com o registro principal do MySQL:

| Campo | API | MySQL | Situação |
|---|---|---|---|
| ID | `540979` | `540979` | Compatível |
| Tipo | `PL` | `PL` | Compatível |
| Número | `2913` | `2913` | Compatível |
| Ano | `2021` | `2021` | Compatível |
| Ementa | `Cria o Selo Verde Cacau Cabruca.` | Mesmo texto | Compatível |
| Status interno | `TRANSFORMADA_EM_NORMA` | `TRANSFORMADA_EM_NORMA` | Compatível |
| Atualização | `2026-09-27T23:48:26` | `2026-09-27 23:48:26` | Mesmo valor, formatos diferentes |

A API também retornou informações adicionais porque o endpoint reúne dados relacionados de outras tabelas locais:

- `autor`: tabela de autores;
- `projeto_autor`: relacionamento entre proposição e autor;
- `tramitacao`: histórico de tramitações.

Portanto, o fato de a consulta simples ao MySQL mostrar somente os campos da tabela `projeto_lei` não significa que a API buscou esses dados na Câmara. O detalhe da API realiza consultas adicionais no próprio MySQL local.

---

## 3. Ajuste de apresentação realizado

A resposta original apresentava:

```json
"detalhe": "Ordinária nº 14877/2024"
```

O formato foi ajustado para:

```json
"detalhe": "Lei Ordinária nº 14877/2024"
```

Esse ajuste é feito em:

```text
backend/app/services/presentation.py
```

A mudança é somente de apresentação. O valor persistido no banco continua sendo:

```text
lei_tipo = Ordinária
lei_numero = 14877/2024
```

---

## 4. Estrutura do backend

```text
backend/
├── app/
│   ├── __init__.py
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── entities.py
│   ├── repositories/
│   │   ├── __init__.py
│   │   ├── favoritos.py
│   │   └── proposicoes.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── api.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── etl.py
│   │   └── presentation.py
│   ├── config.py
│   ├── db.py
│   └── main.py
├── tests/
│   ├── conftest.py
│   └── test_api.py
├── .env.example
├── requirements.txt
└── run.sh
```

### Responsabilidade dos módulos

| Módulo | Responsabilidade |
|---|---|
| `main.py` | Cria a aplicação FastAPI e registra o router. |
| `api/routes.py` | Define os endpoints HTTP e injeta a sessão do banco. |
| `config.py` | Lê configurações do arquivo `.env`. |
| `db.py` | Cria o engine SQLAlchemy e as sessões. |
| `models/entities.py` | Mapeia as tabelas MySQL para classes Python. |
| `repositories/proposicoes.py` | Faz consultas de proposições, autores, tramitações e favoritos. |
| `repositories/favoritos.py` | Inclui e remove favoritos. |
| `schemas/api.py` | Define contratos de entrada e saída com Pydantic. |
| `services/presentation.py` | Converte estados internos em rótulos amigáveis para a interface. |
| `services/etl.py` | Dispara o ETL em segundo plano e bloqueia concorrência. |
| `tests/conftest.py` | Prepara um banco SQLite isolado para testes. |
| `tests/test_api.py` | Testa os endpoints da Fase 4. |

---

## 5. Origem dos dados

### 5.1 Consultas públicas

As seguintes rotas consultam o MySQL local por meio do SQLAlchemy:

```text
GET /health
GET /proposicoes
GET /proposicoes/{id}
GET /proposicoes/{id}/autores
GET /proposicoes/{id}/tramitacoes
GET /proposicoes/{id}/linha-do-tempo
GET /favoritos
POST /favoritos
DELETE /favoritos/{proposicao_id}
```

Essas rotas não importam `requests`, `httpx` ou `etl.extract`.

### 5.2 Sincronização

A única rota que pode iniciar acesso à API Dados Abertos é:

```text
POST /etl/sincronizar
```

O processamento acontece em segundo plano e segue este fluxo:

```text
backend/app/services/etl.py
            │
            ▼
      etl/pipeline.py
            │
            ├── etl/extract.py
            ├── etl/transform.py
            └── etl/load.py
                    │
                    ▼
                MySQL local
```

A sincronização não deve ser entendida como uma consulta dinâmica feita pela FastAPI. Ela é uma operação de atualização do banco.

---

## 6. Configuração

Criar o arquivo `.env` na raiz do projeto:

```bash
cp backend/.env.example .env
```

Exemplo:

```dotenv
ENVIRONMENT=development
DATABASE_URL=mysql+mysqlconnector://legis_app:COLOQUE_SUA_SENHA@127.0.0.1:3306/legis
ADMIN_TOKEN=COLOQUE_ADMIN_TOKEN
DEFAULT_USER_ID=1
ETL_CONFIG_PATH=etl/config.json
```

A variável mais importante é:

```dotenv
DATABASE_URL=mysql+mysqlconnector://usuario:senha@host:porta/banco
```

Ela determina qual banco a FastAPI consulta.

---

## 7. Preparação do MySQL

Executar as migrations na ordem:

```bash
mysql -u root -p < database/migrations/001_create_schema.sql
mysql -u root -p legis < database/migrations/002_add_indexes.sql
mysql -u root -p legis < database/migrations/003_add_etl_metadata.sql
mysql -u root -p legis < database/seeds/001_seed_inicial.sql
```

O seed contém, entre outros registros:

- a proposição `540979`, PL `2913/2021`;
- o autor `160666`, Félix Mendonça Júnior;
- tramitações da proposição;
- usuário local `1` para teste de favoritos.

O seed é idempotente: pode ser executado novamente sem duplicar proposições, autores ou tramitações.

---

## 8. Execução local

Na raiz do projeto:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
cp backend/.env.example .env
```

Iniciar a API:

```bash
./backend/run.sh
```

Ou manualmente:

```bash
export PYTHONPATH="$PWD/backend"
uvicorn app.main:app --reload --app-dir backend
```

Endereços:

```text
API:         http://127.0.0.1:8000
Swagger:     http://127.0.0.1:8000/docs
ReDoc:       http://127.0.0.1:8000/redoc
OpenAPI:     http://127.0.0.1:8000/openapi.json
Health:      http://127.0.0.1:8000/health
```

O endpoint `/health` informa:

```json
{
  "status": "ok",
  "banco": "ok",
  "fonte_dados": "mysql_local"
}
```

---

## 9. Endpoints implementados

| Método | Endpoint | Função |
|---|---|---|
| GET | `/health` | Verifica a aplicação e o banco local. |
| GET | `/proposicoes` | Lista proposições com filtros e paginação. |
| GET | `/proposicoes/{id}` | Retorna o detalhe tratado. |
| GET | `/proposicoes/{id}/autores` | Retorna autores da proposição. |
| GET | `/proposicoes/{id}/tramitacoes` | Retorna o histórico de tramitações. |
| GET | `/proposicoes/{id}/linha-do-tempo` | Retorna a linha do tempo da proposição. |
| GET | `/favoritos` | Lista favoritos do usuário. |
| POST | `/favoritos` | Cria um favorito. |
| DELETE | `/favoritos/{proposicao_id}` | Remove um favorito. |
| POST | `/etl/sincronizar` | Inicia uma sincronização controlada do ETL. |

---

## 10. Regras de resposta

A API:

- retorna dados tratados;
- não expõe o payload bruto da Câmara;
- não retorna `uri_api` como parte da resposta principal;
- converte `status_interno` em código e rótulo;
- informa `atualizado_em`;
- permite ausência de autor sem erro;
- permite ausência de tramitação sem erro;
- responde `404` quando a proposição não existe;
- valida parâmetros de pesquisa;
- limita a paginação a 100 registros por página;
- impede concorrência no endpoint de sincronização;
- executa a sincronização em segundo plano.

Exemplo de resposta tratada:

```json
{
  "id": 540979,
  "titulo": "Cria o Selo Verde Cacau Cabruca.",
  "tipo": "PL",
  "numero": "2913",
  "ano": 2021,
  "status": {
    "codigo": "TRANSFORMADA_EM_NORMA",
    "rotulo": "Transformada em Norma",
    "detalhe": "Lei Ordinária nº 14877/2024",
    "vigencia_verificada": false
  },
  "atualizado_em": "2026-09-27T23:48:26"
}
```

---

## 11. Testes automatizados

Executar:

```bash
pytest -q
```

Os testes utilizam SQLite isolado e não acessam:

- o MySQL de desenvolvimento;
- a API Dados Abertos;
- o banco de produção.

Cenários cobertos:

1. health check;
2. listagem de proposições;
3. tradução do status;
4. ausência de payload bruto;
5. detalhe da proposição;
6. retorno `404`;
7. autores;
8. tramitações;
9. linha do tempo;
10. favoritos idempotentes;
11. validação de ano;
12. proteção do endpoint de sincronização.

Resultado validado:

```text
6 passed
```

---

## 12. Validação manual da origem local

### 12.1 Consultar pela API

```bash
curl --request GET \
  --url http://127.0.0.1:8000/proposicoes/540979
```

### 12.2 Consultar a mesma proposição no MySQL

```sql
USE legis;

SELECT
    id_projeto,
    sigla_tipo,
    numero,
    ano,
    ementa,
    status_interno,
    atualizado_em
FROM projeto_lei
WHERE id_projeto = 540979;
```

### 12.3 Confirmar autores

```sql
SELECT
    a.id_autor,
    a.nome,
    a.tipo,
    pa.proponente,
    pa.ordem_assinatura
FROM autor a
JOIN projeto_autor pa ON pa.id_autor = a.id_autor
WHERE pa.id_projeto = 540979;
```

### 12.4 Confirmar última tramitação

```sql
SELECT
    id_tramitacao,
    sequencia,
    data_hora,
    sigla_orgao,
    descricao_situacao,
    descricao_tramitacao,
    despacho,
    atualizado_em
FROM tramitacao
WHERE id_projeto = 540979
ORDER BY data_hora DESC, sequencia DESC
LIMIT 1;
```

Essas consultas explicam por que a API retorna mais informações do que a consulta direta somente na tabela `projeto_lei`: o detalhe agrega tabelas relacionadas do próprio MySQL.

---

## 13. Insomnia

Importar:

```text
docs/insomnia/legis-fase4.json
```

Configurar:

```text
base_url = http://127.0.0.1:8000
proposicao_id = 540979
user_id = 1
admin_token = COLOQUE_ADMIN_TOKEN
```

Testar na sequência:

```text
GET /health
GET /proposicoes
GET /proposicoes/540979
GET /proposicoes/540979/autores
GET /proposicoes/540979/tramitacoes
GET /proposicoes/540979/linha-do-tempo
GET /favoritos
POST /favoritos
DELETE /favoritos/540979
```

A rota de sincronização deve ser utilizada somente quando se deseja atualizar o banco:

```text
POST /etl/sincronizar
```

---

## 14. Limitações atuais do MVP

- O usuário dos favoritos é identificado pelo header `X-User-Id`;
- autenticação completa ainda não foi implementada;
- notificações estão previstas no modelo, mas o envio real ainda não foi implementado;
- o Flutter será desenvolvido em uma etapa posterior;
- a sincronização depende das configurações e credenciais do MySQL local;
- o endpoint de sincronização deve ser protegido com um token administrativo fora do ambiente de desenvolvimento.

---

## 15. Critério de conclusão da Fase 4

A fase é considerada concluída quando:

- o MySQL contém os dados tratados pelo ETL;
- a FastAPI inicia localmente;
- `/health` informa `fonte_dados: mysql_local`;
- o Swagger está disponível em `/docs`;
- o Insomnia consulta a API local;
- os endpoints não acessam diretamente a Câmara;
- a proposição `540979` pode ser conferida no MySQL e na API;
- os testes automatizados passam;
- a sincronização do ETL é explícita, controlada e separada das consultas públicas.
