# LEGIS — Frontend Flutter integrado

Este pacote contém somente o frontend Flutter: telas responsivas, assets da marca e integração HTTP com o backend FastAPI. O app não consulta diretamente a Câmara dos Deputados e não inclui conjunto de dados fictícios ativo. O fluxo de dados legislativos é: **API de Dados Abertos da Câmara → ETL → MySQL → FastAPI → Flutter**.

## Execução

Na raiz do projeto Flutter, defina uma base URL acessível pelo dispositivo e instale as dependências:

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android Emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`. Em dispositivo físico, use o IP do computador na rede local. O FastAPI deve escutar em `0.0.0.0` e a origem do Flutter Web deve estar autorizada no CORS do backend. Use HTTPS em implantação pública.

## Integrações

- **Explorar/Home/detalhes:** pesquisa no banco local por ementa, número ou autor, com filtros por tipo, ano e situação, paginação e chamadas dos detalhes, autores e tramitações.
- **Cadastro/login/perfil/senha:** `POST /auth/register`, `POST /auth/login`, `GET/PATCH /auth/me`, `POST /auth/change-password` e `POST /auth/logout`. A sessão Bearer opaca fica em armazenamento seguro no app; senha não é persistida no dispositivo.
- **Favoritos:** CRUD autenticado (`/favoritos`), associados ao usuário no banco.
- **Preferências:** `GET/PATCH /usuarios/me/preferencias`, persistidas por conta. Opções de nova proposição e movimentações de favoritos são aplicadas pelo ETL. Votações e comunicados gerais estão desabilitados enquanto não houver fonte/serviço correspondente.
- **Notificações in-app:** `GET /notificacoes` e `PATCH /notificacoes/{id}/lida`. Só são geradas pelo ETL quando uma proposição/tramitação oficial nova é realmente carregada e a preferência do usuário permite; são deduplicadas no banco. Não há push nem envio por mensageria.

## Alterações backend/ETL necessárias

Além desta pasta Flutter, foram alterados `backend/` e `etl/` no pacote complementar. Para MySQL, aplique as migrations existentes em ordem e depois `database/migrations/006_user_sessions_and_preferences.sql`. A migration adiciona `preferencias_json`, sessão por hash e índices de deduplicação. Não há migração automática durante a inicialização.

As rotas de usuário exigem migration 006. O ETL deve executar normalmente após isso para as novas proposições/tramitações virarem notificações in-app. Contas criadas antes dessa mudança recebem defaults ao abrir e salvar Preferências.

## Limitações explícitas

- Recuperação de senha por e-mail não está habilitada: o backend não possui provedor de envio/token de redefinição. A tela informa isso e não confirma envio fictício.
- Notificações são somente in-app; não há push/FCM, e-mail ou mensageria.
- A API interna usa dados locais do MySQL; o frontend não deve ser exposto antes de operar ETL e banco de forma contínua.
- Termos e Privacidade existentes ainda precisam de revisão jurídica antes de publicação.

## Validação realizada nesta entrega

A suíte backend/ETL passou em SQLite: testes de conta/sessão, favoritos por Bearer, perfil, preferências, isolamento e leitura de notificações, busca por autor e geração de notificações a partir dos eventos ETL. A integração MySQL foi pulada porque `LEGIS_TEST_MYSQL_URL` não estava configurada. O SDK Flutter/Dart não está instalado neste ambiente; portanto `flutter pub get`, `flutter analyze` e compilação não puderam ser executados aqui. O frontend foi revisado estaticamente; valide-o localmente com os comandos acima antes de publicar.
