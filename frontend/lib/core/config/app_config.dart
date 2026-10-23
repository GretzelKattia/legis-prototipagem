/// URL do FastAPI para navegador, emulador ou dispositivo físico.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Mantenha em sincronia com `version:` do pubspec.yaml.
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  /// Canal de suporte exibido na tela "Ajuda e suporte". Troque pelo e-mail real.
  static const String supportEmail = 'suporte@legis.app';
}
