import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Routes {
  Routes._();

  static const String gate = '/';
  static const String login = '/login';
  static const String changePassword = '/change-password';
  static const String shops = '/shops';
  static const String menu = '/menu';
  static const String cart = '/cart';
  static const String tracking = '/tracking';
  static const String history = '/history';
}

void showAppSnack(String message, {bool isError = false}) {
  final messenger = messengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
}
