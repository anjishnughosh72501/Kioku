/// Application configuration and environment constants.
class AppConfig {
  AppConfig._();

  /// Configurable backend relay / API URL.
  /// Override at build/run time with: --dart-define=BACKEND_URL=https://api.yourdomain.com
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static const String appScheme = 'kioku';
  static const String appHost = 'kioku.app';
  static const String appPrivacyUrl = 'https://kioku.app/privacy';
  static const String appTermsUrl = 'https://kioku.app/terms';
}
