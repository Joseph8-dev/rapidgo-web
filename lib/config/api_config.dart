class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://goevent.work',
  );

  static const String prefix = '/api/rapidgo';

  static const Duration timeout = Duration(seconds: 20);

  static const Duration orderPollInterval = Duration(seconds: 5);

  static const Duration pollCeiling = Duration(minutes: 45);

  static const String rate = '/api/rate/current';

  static const String config = '$prefix/config';
  static const String login = '$prefix/auth/login';
  static const String changePassword = '$prefix/auth/change-password';
  static const String me = '$prefix/me';
  static const String balance = '$prefix/balance';
  static const String shops = '$prefix/shops';
  static String shop(int id) => '$prefix/shops/$id';
  static String catalog(int id) => '$prefix/shops/$id/catalog';
  static const String orders = '$prefix/orders';
  static String order(int id) => '$prefix/orders/$id';
  static String cancelOrder(int id) => '$prefix/orders/$id/cancel';
  static String confirmOrder(int id) => '$prefix/orders/$id/confirm';
  static const String withdrawConfig = '$prefix/withdrawals/config';
  static const String withdrawAccounts = '$prefix/withdrawals/accounts';
  static const String withdrawals = '$prefix/withdrawals';

  static const String pushToken = '$prefix/push/token';

  static String? resolveMedia(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final raw = url.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;

    final base = Uri.parse(baseUrl);
    if (!parsed.hasScheme) {
      return base.replace(path: parsed.path, query: parsed.query).toString();
    }
    return parsed
        .replace(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null)
        .toString();
  }
}
