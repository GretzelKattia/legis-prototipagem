# API FastAPI — Fase 4

A API consulta somente o banco local `legis`. O ETL é o componente responsável por acessar a Câmara, extrair os dados e gravar as versões tratadas no MySQL.

Assim, o Insomnia e o frontend não acessam diretamente a API da Câmara.

## Configuração

A aplicação lê as variáveis de um arquivo `.env` na raiz do projeto:

```dotenv
ENVIRONMENT=development
DATABASE_URL=mysql+mysqlconnector://legis_app:COLOQUE_SUA_SENHA@127.0.0.1:3306/legis
ADMIN_TOKEN=COLOQUE_ADMIN_TOKEN
DEFAULT_USER_ID=1
ETL_CONFIG_PATH=etl/config.json
```

Para criar o arquivo:

```bash
cp backend/.env.example .env
```

## Execução

```bash
source .venv/bin/activate
./backend/run.sh
```

A documentação interativa fica disponível em:

- Swagger UI: <http://127.0.0.1:8000/docs>
- ReDoc: <http://127.0.0.1:8000/redoc>
- OpenAPI: <http://127.0.0.1:8000/openapi.json>

## Endpoints

| Método | Rota | Objetivo |
|---|---|---|
| GET | `/health` | Verifica aplicação e banco. |
| GET | `/proposicoes` | Lista proposições com filtros e paginação. |
| GET | `/proposicoes/{id}` | Retorna o detalhe tratado. |
| GET | `/proposicoes/{id}/autores` | Lista autores, inclusive lista vazia. |
| GET | `/proposicoes/{id}/tramitacoes` | Lista o histórico tratado. |
| GET | `/proposicoes/{id}/linha-do-tempo` | Alias de apresentação do histórico. |
| GET | `/favoritos` | Lista favoritos do usuário informado. |
| POST | `/favoritos` | Cria um favorito sem duplicar a relação. |
| DELETE | `/favoritos/{proposicao_id}` | Remove um favorito. |
| POST | `/etl/sincronizar` | Dispara o ETL em segundo plano. |
| GET | `/etl/status` | Retorna a última execução persistida do ETL. |
| POST | `/proposicoes/{id}/verificar-vigencia` | Consulta fonte oficial e registra revisão administrativa auditável; exige `X-Admin-Token`. |

## Pesquisa e paginação

`GET /proposicoes` aceita:

- `q`: busca por ementa ou número, máximo de 120 caracteres;
- `tipo`: sigla alfabética, como `PL` ou `PEC`;
- `ano`: entre 1900 e 2100;
- `status`: código tratado, como `EM_TRAMITACAO`;
- `page`: página a partir de `1`;
- `per_page`: entre `1` e `100`.

Exemplo:

```bash
curl 'http://127.0.0.1:8000/proposicoes?q=cacau&tipo=PL&ano=2021&page=1&per_page=10'
```

A resposta contém `items` e `meta`, com `pagina`, `por_pagina`, `total` e `total_paginas`.

## Dados tratados

A API não devolve `uri_api`, payload bruto ou códigos isolados como resposta principal. O status é apresentado assim:

```json
{
  "codigo": "TRANSFORMADA_EM_NORMA",
  "rotulo": "Transformada em Norma",
  "detalhe": "Lei Ordinária nº 14.877/2024",
  "vigencia_verificada": false,
  "situacao_juridica": null,
  "inicio_vigencia": null,
  "fonte_vigencia": null,
  "verificada_em": null
}
```

As respostas de proposição incluem `atualizado_em`. Quando não houver autor ou tramitação, a API devolve uma lista vazia e não gera erro.

## Favoritos

O MVP usa o header `X-User-Id` somente como identificador local de usuário; ele **não autentica nem comprova identidade**. Valores `<= 0` são rejeitados. Se não for enviado, usa `DEFAULT_USER_ID`.

```bash
curl -H 'X-User-Id: 1' http://127.0.0.1:8000/favoritos
curl -X POST http://127.0.0.1:8000/favoritos \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: 1' \
  -d '{"proposicao_id":540979}'
```

O seed inicial cria o usuário local `1`. A mesma proposição pode ser enviada mais de uma vez sem duplicar a relação.

Antes de produção, implemente autenticação real e autorização do usuário associado; não confie neste cabeçalho recebido do cliente.

## Revisão de vigência jurídica

Somente após migrações até 005, o administrador pode registrar uma avaliação. O serviço exige HTTPS em host oficial permitido, faz GET sem seguir redirecionamentos, requer resposta HTTP 200, confirma o número da norma na página e o trecho literal citado. O revisor informa a conclusão e datas; o serviço não presume vigência a partir da conversão em norma.

```bash
curl -X POST http://127.0.0.1:8000/proposicoes/540979/verificar-vigencia \
  -H 'X-Admin-Token: COLOQUE_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"situacao_juridica":"NAO_CONSTA_REVOGACAO_EXPRESSA","fonte_url":"https://www2.camara.leg.br/legin/fed/lei/2024/lei-14877-4-junho-2024-795712-norma-pl.html","evidencia_texto":"Situação: Não consta revogação expressa Indexação CACAUICULTURA","revisor":"Nome do revisor"}'
```

Cada revisão conserva URL, citação, revisor declarado, data, status HTTP, SHA-256 do conteúdo e histórico em `verificacao_vigencia`. `NAO_CONSTA_REVOGACAO_EXPRESSA` não significa vigência verificada. Para `vigencia_verificada=true`, a fonte citada deve declarar explicitamente “Vigente” ou “Em vigor”; a cláusula original de início de vigência, ou somente a ausência de revogação expressa, não basta. As datas informadas pelo revisor devem ser conferidas na publicação e no texto oficial. Falhas de rede, fonte não oficial, trecho ausente ou número incompatível não atualizam o projeto.

## Sincronização ETL

O endpoint responde `202 Accepted` e não mantém a requisição aberta durante toda a extração. Uma segunda execução enquanto a primeira estiver ativa recebe `409 Conflict`.

Em desenvolvimento:

```bash
curl -X POST http://127.0.0.1:8000/etl/sincronizar \
  -H 'X-Admin-Token: COLOQUE_ADMIN_TOKEN'
```

Fora de `development` e `test`, o token administrativo deve ser configurado com segurança em `ADMIN_TOKEN`.

Para execução periódica, use o Windows Task Scheduler ou cron conforme `docs/agendamento_etl.md`. O FastAPI não é usado como agendador persistente.

```bash
curl http://127.0.0.1:8000/etl/status
```

O status pode ser `EM_EXECUCAO`, `SUCESSO`, `PARCIAL` ou `ERRO`. `PARCIAL` significa que `max_pages` foi atingido enquanto a última página ainda estava cheia; nesse caso, a cobertura não deve ser apresentada como completa.

## Testes automatizados

Os testes comuns usam SQLite isolado e mocks HTTP. A partir da raiz:

```bash
pytest -q
```

O teste `backend/tests/test_mysql_integration.py` pode ser executado contra MySQL 8 real com uma conta temporária autorizada a criar/excluir schemas, definindo `LEGIS_TEST_MYSQL_URL`. O teste pula explicitamente se essa variável não estiver configurada.

## Problemas comuns

### `ModuleNotFoundError: No module named 'app'`

Execute a partir da raiz e use o script oficial:

```bash
./backend/run.sh
```

Os testes na raiz já configuram os caminhos de import no pytest. Para executar diretamente a API, use `./backend/run.sh`.

### Erro de conexão com MySQL

Confirme se o serviço está ativo, se o banco foi criado, se as migrations foram aplicadas e se `DATABASE_URL` está correto.

### `404 Proposição não encontrada`

A API está respondendo corretamente: o ID ainda não está no banco local. Execute o seed ou rode o ETL.

## Origem dos dados e separação entre API e ETL

Os endpoints abaixo fazem consultas SQL no MySQL local por meio de SQLAlchemy:

- `GET /health`;
- `GET /proposicoes`;
- `GET /proposicoes/{id}`;
- `GET /proposicoes/{id}/autores`;
- `GET /proposicoes/{id}/tramitacoes`;
- `GET /proposicoes/{id}/linha-do-tempo`;
- `GET /favoritos`;
- `POST /favoritos`;
- `DELETE /favoritos/{proposicao_id}`.

Nenhuma dessas rotas importa `requests`, `httpx` ou `etl.extract`.

A API Dados Abertos somente é acessada quando alguém chama explicitamente:

```text
POST /etl/sincronizar
```

Esse endpoint chama `backend/app/services/etl.py`, que importa `etl/pipeline.py`. O pipeline então executa:

```text
etl/extract.py  →  etl/transform.py  →  etl/load.py  →  MySQL local
```

Portanto, a sincronização é uma operação de atualização do banco, não uma fonte de resposta dos endpoints públicos.

O retorno de `GET /health` inclui:

```json
{
  "status": "ok",
  "banco": "ok",
  "fonte_dados": "mysql_local"
}
```
