import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenshotGuard {
  ScreenshotGuard._();
  static final ScreenshotGuard instance = ScreenshotGuard._();

  static const _channel = MethodChannel('co.nosus.app/security');

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }
}
