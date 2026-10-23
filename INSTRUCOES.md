# Patch de integração backend/ETL

Este pacote contém apenas os arquivos que precisam ser adicionados/substituídos na árvore do projeto original. Copie as pastas `backend/`, `etl/`, `database/` e `docs/` para a raiz do repositório, preservando o caminho, e revise o diff antes de aplicar.

## Ordem segura

1. Faça backup do banco e dos diretórios existentes. Pare a API e a execução do ETL durante a migration.
2. Com MySQL 8.0+ e as migrations 001–005 já aplicadas, aplique **uma única vez** `database/migrations/006_user_sessions_and_preferences.sql` (`mysql ... < ...`). A migration adiciona JSON de preferências, tabela de sessões (só hash de token), coluna gerada para deduplicação e índices únicos.
3. Configure `ENVIRONMENT=production` e os parâmetros de conexão existentes. Em production, `/favoritos` exige Bearer; `X-User-Id` não é aceito como identidade. Use HTTPS e configure CORS para a origem real do app.
4. Inicie a API e execute o ETL normalmente. O ETL gera avisos somente para registros oficiais novos e preferências salvas; não há push/e-mail. A repetição de evento já carregado é deduplicada no MySQL.
5. Testes offline: `python3 -m pytest -q` na raiz do projeto. O teste de integração MySQL requer `LEGIS_TEST_MYSQL_URL` configurada.

O cadastro/login, alteração de perfil/senha, favoritos, preferências e notificações in-app são persistidos no MySQL pelas novas rotas. Recuperação de senha por e-mail e notificações push permanecem desativadas porque não há serviço de e-mail/FCM no projeto. Não execute a migration novamente: ela não é idempotente e deve ser registrada no mecanismo de migração que sua equipe usa.
