import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Only named conversion events and non-personal job IDs are sent to Meta.
/// Native auto-logging and advertising ID collection are disabled separately.
class MetaEventsService {
  MetaEventsService({FacebookAppEvents? sdk, bool? enabled})
    : _sdk = sdk ?? FacebookAppEvents(),
      _enabled =
          enabled ??
          const bool.fromEnvironment('META_EVENTS_ENABLED', defaultValue: true);

  static final instance = MetaEventsService();
  final FacebookAppEvents _sdk;
  final bool _enabled;
  bool _ready = false;

  Future<void> initialize() async {
    if (!_enabled ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final appId = await _sdk.getApplicationId();
      if (appId == null || !RegExp(r'^[1-9][0-9]+$').hasMatch(appId)) {
        debugPrint('[Meta] Events disabled: configure a real Meta App ID.');
        return;
      }
      await _sdk.setAutoLogAppEventsEnabled(false);
      await _sdk.setAdvertiserIdCollectionEnabled(false);
      await _sdk.activateApp();
      _ready = true;
    } catch (_) {
      debugPrint('[Meta] Events unavailable; app startup will continue.');
    }
  }

  Future<void> _send(Future<void> Function() action) async {
    if (!_ready) return;
    try {
      await action();
    } catch (_) {
      // Analytics must never turn a successful user action into an error.
      debugPrint('[Meta] Event could not be recorded.');
    }
  }

  Future<void> login() => _send(() => _sdk.logEvent(name: 'worker_login'));

  Future<void> registrationCompleted() => _send(
    () => _sdk.logCompletedRegistration(registrationMethod: 'phone_otp'),
  );

  Future<void> jobViewed(int id) => _send(
    () => _sdk.logEvent(
      name: 'fb_mobile_content_view',
      parameters: {'fb_content_type': 'job', 'fb_content_id': '$id'},
    ),
  );

  Future<void> jobSaved(int id) => _send(
    () => _sdk.logEvent(name: 'job_saved', parameters: {'job_id': '$id'}),
  );

  Future<void> applicationSubmitted(int id) => _send(
    () => _sdk.logEvent(
      name: 'job_application_submitted',
      parameters: {'job_id': '$id'},
    ),
  );

  Future<void> onboardingContinued() =>
      _send(() => _sdk.logEvent(name: 'onboarding_continued'));

  Future<void> jobsSearched({
    required bool hasQuery,
    required bool hasFilters,
    required int resultCount,
  }) => _send(
    () => _sdk.logEvent(
      name: 'jobs_searched',
      parameters: {
        'has_query': hasQuery ? 1 : 0,
        'has_filters': hasFilters ? 1 : 0,
        'result_count': resultCount,
      },
    ),
  );

  Future<void> profileUpdated() =>
      _send(() => _sdk.logEvent(name: 'worker_profile_updated'));

  Future<void> resumeUploaded() =>
      _send(() => _sdk.logEvent(name: 'resume_uploaded'));

  Future<void> resumeRemoved() =>
      _send(() => _sdk.logEvent(name: 'resume_removed'));

  Future<void> jobUnsaved(int id) => _send(
    () => _sdk.logEvent(name: 'job_unsaved', parameters: {'job_id': '$id'}),
  );

  Future<void> applicationWithdrawn() =>
      _send(() => _sdk.logEvent(name: 'job_application_withdrawn'));

  Future<void> employerChatOpened(int id) => _send(
    () => _sdk.logEvent(
      name: 'employer_chat_opened',
      parameters: {'job_id': '$id'},
    ),
  );

  // Opening the dialer is contact intent, not proof of a connected call.
  Future<void> employerDialerOpened(int id) => _send(
    () => _sdk.logEvent(
      name: 'employer_dialer_opened',
      parameters: {'job_id': '$id'},
    ),
  );

  Future<void> employerReviewSubmitted() =>
      _send(() => _sdk.logEvent(name: 'employer_review_submitted'));
}
