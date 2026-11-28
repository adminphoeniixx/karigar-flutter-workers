import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'device_token_service.dart';

/// Where a notification takes the worker, from the system tray or from Alerts.
///
/// Keep this mapping in one place so both always behave alike.
sealed class WorkerPushDestination {
  const WorkerPushDestination();

  static const applications = OpenApplications();
  static const kyc = OpenKyc();
}

/// The Applied tab: status changes, interviews, offers. With
/// [applicationId] that application is brought to the top and highlighted
/// (a hire alert used to drop the karigar at the top of the whole list).
final class OpenApplications extends WorkerPushDestination {
  const OpenApplications({this.applicationId});
  final int? applicationId;
  @override
  bool operator ==(Object other) =>
      other is OpenApplications && other.applicationId == applicationId;
  @override
  int get hashCode => applicationId.hashCode;
}

/// The KYC screen, after a review.
final class OpenKyc extends WorkerPushDestination {
  const OpenKyc();
}

/// One job: a new job alert or an employer's invite.
final class OpenJob extends WorkerPushDestination {
  const OpenJob(this.jobId);
  final int jobId;
  @override
  bool operator ==(Object other) => other is OpenJob && other.jobId == jobId;
  @override
  int get hashCode => jobId.hashCode;
}

/// One chat with an employer.
final class OpenConversation extends WorkerPushDestination {
  const OpenConversation(this.conversationId);
  final int conversationId;
  @override
  bool operator ==(Object other) =>
      other is OpenConversation && other.conversationId == conversationId;
  @override
  int get hashCode => conversationId.hashCode;
}

class WorkerPushRoute {
  static const interviewTypes = <String>{
    'application.interview',
    'application.interview_reminder',
  };

  static final _jobUrl = RegExp(r'/jobs/(\d+)');
  static final _chatUrl = RegExp(r'/messages/(\d+)');

  static int? _id(Object? value) => int.tryParse('${value ?? ''}'.trim());

  /// Reads a push payload or an Alerts row (the list keeps only `url`, so
  /// ids are also read from it).
  static WorkerPushDestination? fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final url = data['url']?.toString() ?? '';
    switch (type) {
      case 'chat.message':
        final id =
            _id(data['conversation_id']) ??
            _id(_chatUrl.firstMatch(url)?.group(1));
        return id == null ? null : OpenConversation(id);
      case 'job.posted' || 'job.invite':
        final id =
            _id(data['job_listing_id']) ??
            _id(data['job_id']) ??
            _id(_jobUrl.firstMatch(url)?.group(1));
        return id == null ? null : OpenJob(id);
      case 'kyc.reviewed':
        return WorkerPushDestination.kyc;
    }
    if (interviewTypes.contains(type) ||
        type.startsWith('application.') ||
        type == 'interview.reminder_call') {
      final id = _id(data['application_id']);
      return id == null
          ? WorkerPushDestination.applications
          : OpenApplications(applicationId: id);
    }
    return null;
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const _registeredTokenKey = 'registered_fcm_token';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final DeviceTokenService _deviceTokens = DeviceTokenService();
  final StreamController<WorkerPushDestination> _openedDestinations =
      StreamController<WorkerPushDestination>.broadcast();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  WorkerPushDestination? _initialDestination;
  Stream<RemoteMessage> get foregroundMessages => Firebase.apps.isEmpty
      ? const Stream<RemoteMessage>.empty()
      : FirebaseMessaging.onMessage;
  Stream<WorkerPushDestination> get openedDestinations =>
      _openedDestinations.stream;

  /// Returns the route that launched a terminated app, at most once.
  WorkerPushDestination? takeInitialDestination() {
    final destination = _initialDestination;
    _initialDestination = null;
    return destination;
  }

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) return;
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (token) => _register(token),
      onError: (Object error) =>
          debugPrint('[FCM] Token refresh failed: $error'),
    );
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
      onError: (Object error) =>
          debugPrint('[FCM] Open handler failed: $error'),
    );
    try {
      final initialMessage = await _messaging.getInitialMessage();
      final destination = initialMessage == null
          ? null
          : WorkerPushRoute.fromData(initialMessage.data);
      if (destination != null) {
        _initialDestination ??= destination;
      }
    } catch (error) {
      debugPrint('[FCM] Unable to read launch notification: $error');
    }

    // The permission prompt waits for the worker, so it must not hold up the
    // splash screen.
    unawaited(_askPermissionThenSync());
  }

  Future<void> _askPermissionThenSync() async {
    try {
      await _messaging.requestPermission();
    } catch (error) {
      debugPrint('[FCM] Permission request failed: $error');
    }
    if (ApiClient.instance.isAuthenticated) await syncToken();
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final destination = WorkerPushRoute.fromData(message.data);
    if (destination != null) {
      _openedDestinations.add(destination);
    }
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
