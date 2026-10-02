import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'navigation.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shops_screen.dart';
import 'services/active_orders_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/catalog_service.dart';
import 'services/config_service.dart';
import 'services/device_service.dart';
import 'services/order_service.dart';
import 'services/rate_service.dart';
import 'services/withdrawal_service.dart';
import 'theme/app_theme.dart';
import 'widgets/go_logo.dart';
import 'widgets/responsive.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RapidGoApp());
}

class RapidGoApp extends StatefulWidget {
  const RapidGoApp({super.key});

  @override
  State<RapidGoApp> createState() => _RapidGoAppState();
}

class _RapidGoAppState extends State<RapidGoApp> {
  late final AuthService _auth;
  late final DeviceService _device;
  late final ApiService _api;
  late final CatalogService _catalog;
  late final OrderService _orders;
  late final ConfigService _config;
  late final ActiveOrdersService _activeOrders;
  late final RateService _rates;
  late final WithdrawalService _withdrawals;

  @override
  void initState() {
    super.initState();

    _auth = AuthService();
    _device = DeviceService();

    _api = ApiService(
      tokenProvider: _auth.readToken,
      onUnauthorized: _handleUnauthorized,
      deviceIdProvider: _device.deviceId,
    );

    _auth.api = _api;

    _catalog = CatalogService(_api);
    _orders = OrderService(_api);
    _config = ConfigService(_api);
    _activeOrders = ActiveOrdersService(_orders);
    _rates = RateService(_api);
    _withdrawals = WithdrawalService(_api);

    unawaited(_config.load());

    unawaited(_auth.restore());
  }

  Future<void> _handleUnauthorized() async {
    _activeOrders.stop();
    await _auth.onUnauthorized();
    if (!mounted) return;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    showAppSnack('Tu sesión expiró. Inicia sesión de nuevo.', isError: true);
  }

  @override
  void dispose() {
    _activeOrders.dispose();
    _rates.dispose();
    _api.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: _auth),
        Provider<ApiService>.value(value: _api),
        Provider<CatalogService>.value(value: _catalog),
        Provider<OrderService>.value(value: _orders),
        Provider<ConfigService>.value(value: _config),
        ChangeNotifierProvider<ActiveOrdersService>.value(value: _activeOrders),
        ChangeNotifierProvider<RateService>.value(value: _rates),
        Provider<WithdrawalService>.value(value: _withdrawals),
        Provider<DeviceService>.value(value: _device),
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
      ],
      child: MaterialApp(
        title: 'Rapidito Monumental',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.dark,
        scrollBehavior: const AppScrollBehavior(),
        home: const _SessionGate(),
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final watcher = context.read<ActiveOrdersService>();

    if (auth.isRestoring) return const _Splash();
    if (!auth.isAuthenticated) {
      watcher.stop();
      return const LoginScreen();
    }
    if (auth.mustChangePassword) return const ChangePasswordScreen(forced: true);

    watcher.start();
    unawaited(context.read<RateService>().ensureFresh());
    return const ShopsScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoLogo(height: 120),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
