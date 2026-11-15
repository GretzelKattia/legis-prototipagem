# Patch de integração backend/ETL

Este pacote contém apenas os arquivos que precisam ser adicionados/substituídos na árvore do projeto original. Copie as pastas `backend/`, `etl/`, `database/` e `docs/` para a raiz do repositório, preservando o caminho, e revise o diff antes de aplicar.

## Ordem segura

1. Faça backup do banco e dos diretórios existentes. Pare a API e a execução do ETL durante a migration.
2. Com MySQL 8.0+ e as migrations 001–005 já aplicadas, aplique **uma única vez**, nesta ordem, `database/migrations/006_user_sessions_and_preferences.sql` e `database/migrations/007_user_topics.sql` (`mysql ... < ...`). A primeira adiciona JSON de preferências, tabela de sessões (só hash de token), coluna gerada para deduplicação e índices únicos; a segunda adiciona o JSON de temas acompanhados à conta.
3. Configure `ENVIRONMENT=production` e os parâmetros de conexão existentes. Em production, `/favoritos` exige Bearer; `X-User-Id` não é aceito como identidade. Use HTTPS e configure CORS para a origem real do app.
4. Inicie a API e execute o ETL normalmente. O ETL gera avisos in-app para registros oficiais novos: quando o usuário tem temas salvos, somente as proposições compatíveis com esses temas geram `NOVA_PROPOSICAO_TEMA`; sem temas, permanece o aviso geral `NOVA_PROPOSICAO`. Novas tramitações continuam sendo avisadas para proposições favoritadas. Não há push/e-mail; a repetição de evento já carregado é deduplicada no MySQL.
5. Testes offline: `python3 -m pytest -q` na raiz do projeto. O teste de integração MySQL requer `LEGIS_TEST_MYSQL_URL` configurada.

O cadastro/login, alteração de perfil/senha, favoritos, preferências, temas e notificações in-app são persistidos no MySQL pelas novas rotas. A tela de Favoritos separa visualmente “Temas acompanhados” de “Proposições acompanhadas”; favoritar uma proposição continua sendo o mecanismo para acompanhar suas novas tramitações. Recuperação de senha por e-mail e notificações push permanecem desativadas porque não há serviço de e-mail/FCM no projeto. Não execute as migrations novamente: elas não são idempotentes e devem ser registradas no mecanismo de migração que sua equipe usa.
