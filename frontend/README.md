# LEGIS — frontend Flutter

Interface mobile em Flutter + Material 3. O app consome **somente a API FastAPI local**; não acessa a API da Câmara diretamente e não implementa push, Firebase ou autenticação real.

## Execução

Na pasta `frontend/`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Valores comuns de `API_BASE_URL`:

- Android Emulator: `http://10.0.2.2:8000`
- iOS Simulator: `http://127.0.0.1:8000`
- celular físico: `http://IP_DA_MAQUINA:8000` e FastAPI escutando no host acessível

Inicie o backend antes do app. O usuário de favoritos segue o contrato atual e envia `X-User-Id: 1`.

## Validação

```bash
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

O sandbox usado para preparar esta entrega não possui Flutter/Dart instalado; portanto os comandos acima precisam ser executados em uma máquina com Flutter SDK. A fonte contém estados de carregamento, vazio, erro e retry e não usa dados fictícios conectados à API.

## Escopo visual

Implementado: inicial, tutorial, home, explorar, detalhes, autores, tramitações, favoritos, notificações informativas, perfil e preferências locais. A tela de notificações é apenas visual, conforme solicitado.
