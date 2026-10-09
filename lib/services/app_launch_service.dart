import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

class AppLaunchService {
  AppLaunchService([ApiClient? client]) : _api = client ?? ApiClient.instance;
  final ApiClient _api;

  Future<Map<String, dynamic>> maintenance() =>
      _api.get(ApiConstants.appMaintenance, query: {'app': 'worker'});

  Future<Map<String, dynamic>> update() => _api.get(
    ApiConstants.appUpdate,
    query: {
      'app': 'worker',
      'platform': Platform.isIOS ? 'ios' : 'android',
      // Keep this in sync with pubspec until package_info_plus is introduced.
      'version': '1.0.0',
    },
  );
}

class AppLaunchState {
  static final update = ValueNotifier<Map<String, dynamic>?>(null);
}
