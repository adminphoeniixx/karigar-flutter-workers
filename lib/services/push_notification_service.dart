import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'device_token_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const _registeredTokenKey = 'registered_fcm_token';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final DeviceTokenService _deviceTokens = DeviceTokenService();
  StreamSubscription<String>? _tokenRefreshSubscription;
  Stream<RemoteMessage> get foregroundMessages => Firebase.apps.isEmpty
      ? const Stream<RemoteMessage>.empty()
      : FirebaseMessaging.onMessage;

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) return;
    await _messaging.requestPermission();
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (token) => _register(token),
      onError: (Object error) =>
          debugPrint('[FCM] Token refresh failed: $error'),
    );

    if (ApiClient.instance.isAuthenticated) await syncToken();
  }

  /// Registers the current FCM token after a login or session restore.
  Future<void> syncToken() async {
    if (Firebase.apps.isEmpty ||
        !ApiClient.instance.isAuthenticated ||
        _platform == null) {
      return;
    }
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (error) {
      // Push setup must never prevent the user from signing in.
      debugPrint('[FCM] Unable to register device token: $error');
    }
  }

  /// Removes this device from the backend before the auth token is cleared.
  Future<void> unregisterToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_registeredTokenKey);
    if (Firebase.apps.isEmpty) {
      await prefs.remove(_registeredTokenKey);
      return;
    }
    try {
      token ??= await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _deviceTokens.unregister(token);
      }
      await prefs.remove(_registeredTokenKey);
    } catch (error) {
      // Logout must still complete if Firebase or the device-token API is down.
      debugPrint('[FCM] Unable to unregister device token: $error');
    }
  }

  Future<void> _register(String token) async {
    final platform = _platform;
    if (!ApiClient.instance.isAuthenticated || platform == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final previousToken = prefs.getString(_registeredTokenKey);
      if (previousToken != null && previousToken != token) {
        try {
          await _deviceTokens.unregister(previousToken);
        } catch (error) {
          debugPrint('[FCM] Unable to remove stale device token: $error');
        }
      }

      await _deviceTokens.register(token: token, platform: platform);
      await prefs.setString(_registeredTokenKey, token);
    } catch (error) {
      debugPrint('[FCM] Unable to register refreshed device token: $error');
    }
  }

  DevicePlatform? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => DevicePlatform.android,
    TargetPlatform.iOS => DevicePlatform.ios,
    _ => null,
  };
}
