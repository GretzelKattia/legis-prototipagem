# Agendamento periódico do ETL

## Decisão arquitetural

O ETL não deve depender de um agendador interno do FastAPI. `BackgroundTasks` é adequado para uma execução manual curta, mas não é um mecanismo confiável de jobs: a execução pode ser interrompida quando o processo web reinicia e não há garantia de execução única entre múltiplos workers.

Para o TCC, a solução recomendada é um agendador do próprio sistema operacional:

- **Windows:** Task Scheduler;
- **Linux:** cron ou systemd timer.

A FastAPI continua oferecendo `POST /etl/sincronizar` para execução manual administrativa e `GET /etl/status` para consulta do último estado persistido.

## Windows Task Scheduler

1. Configure as variáveis de ambiente do usuário ou da máquina:

```powershell
[Environment]::SetEnvironmentVariable('LEGIS_DB_HOST', '127.0.0.1', 'User')
[Environment]::SetEnvironmentVariable('LEGIS_DB_PORT', '3306', 'User')
[Environment]::SetEnvironmentVariable('LEGIS_DB_USER', 'legis_app', 'User') #root
[Environment]::SetEnvironmentVariable('LEGIS_DB_PASSWORD', 'SENHA_LOCAL', 'User') #root
[Environment]::SetEnvironmentVariable('LEGIS_DB_DATABASE', 'legis', 'User') #legis
```

2. Teste manualmente na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_etl.ps1
```

3. Abra **Agendador de Tarefas** → **Criar Tarefa**.
4. Em **Disparadores**, escolha uma repetição a cada 6 ou 12 horas.
5. Em **Ações**, use:

```text
Programa: powershell.exe
Argumentos: -NoProfile -ExecutionPolicy Bypass -File "C:\caminho\legis\scripts\run_etl.ps1"
Iniciar em: C:\caminho\legis
```

6. Marque a opção para executar mesmo sem o usuário conectado, se isso for necessário no computador da apresentação.
7. Verifique `etl/data/status.jsonl` e `GET /etl/status` após a execução.

## Linux cron

Configure as variáveis no ambiente do usuário e execute:

```bash
crontab -e
```

Exemplo a cada 6 horas:

```cron
0 */6 * * * cd /caminho/legis && /caminho/legis/scripts/run_etl.sh >> /caminho/legis/etl/data/cron.log 2>&1
```

## Observação para o TCC

Configurar o Windows Task Scheduler já é suficiente para demonstrar atualização periódica real. Não é necessário adicionar Celery, Redis ou um scheduler dentro do FastAPI nesta fase.
