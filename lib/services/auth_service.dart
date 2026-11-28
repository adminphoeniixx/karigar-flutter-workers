import 'dart:async';
import 'package:flutter/foundation.dart';
import 'meta_events_service.dart';
import '../constants/api_constants.dart';
import '../models/api_models.dart';
import 'api_client.dart';
import 'push_notification_service.dart';
import 'worker_api_service.dart';

class AuthService {
  AuthService([ApiClient? client]) : _api = client ?? ApiClient.instance;
  final ApiClient _api;
  Future<int> sendOtp(String phone) async =>
      ((await _api.post(ApiConstants.otpSend, {'phone': phone}))['cooldown']
              as num?)
          ?.toInt() ??
      30;
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final json = await _api.post(ApiConstants.otpVerify, {
      'phone': phone,
      'otp': otp,
      'role': 'worker',
      'device_name': 'Super Karigar Worker',
    });
    final result = AuthResult.fromJson(json);
    if (!result.user.isWorker) {
      throw ApiException(
        'This account does not have worker access. Sign in with a worker account or contact support.',
        statusCode: 403,
      );
    }
    await _api.setToken(result.token);
    WorkerApiService.forgetCurrentUser();
    await PushNotificationService.instance.syncToken();
    unawaited(MetaEventsService.instance.login());
    return result;
  }

  Future<UserModel> me() async => UserModel.fromJson(
    Map<String, dynamic>.from((await _api.get(ApiConstants.me))['user'] as Map),
  );
  Future<MeModel> fetchMe() async =>
      MeModel.fromJson(await _api.get(ApiConstants.me));
  /// Always signs out on this phone. Without internet the server session
  /// can't be closed, but the worker must not be left half signed in.
  Future<void> logout() async {
    try {
      await PushNotificationService.instance.unregisterToken();
      await _api.post(ApiConstants.logout);
    } on ApiException catch (error) {
      debugPrint('[AUTH] Server logout failed: ${error.message}');
    } finally {
      await _api.setToken(null);
      WorkerApiService.forgetCurrentUser();
    }
  }

  Future<void> deleteAccount() async {
    // Keep the current session intact if the server refuses deletion (for
    // example, for the shared test account).
    await _api.delete('${ApiConstants.account}?confirm=1', {'confirm': true});
    await PushNotificationService.instance.unregisterToken();
    await _api.setToken(null);
  }

  Future<AccountDeletionSummary> deletionSummary() async =>
      AccountDeletionSummary.fromJson(
        await _api.get(ApiConstants.accountDeletion),
      );
}
