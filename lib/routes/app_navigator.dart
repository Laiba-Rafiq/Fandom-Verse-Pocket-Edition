import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator._();

  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<T?> replace<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).pushReplacement<T, void>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static void backToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
