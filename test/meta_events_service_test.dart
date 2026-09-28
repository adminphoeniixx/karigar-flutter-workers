import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/services/meta_events_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.oddbit.id/facebook_app_events');
  final calls = <MethodCall>[];
  var appId = '123456789';
  var fail = false;

  setUp(() {
    calls.clear();
    appId = '123456789';
    fail = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (fail) throw PlatformException(code: 'unavailable');
          if (call.method == 'getApplicationId') return appId;
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('disabled tracking makes no platform calls', () async {
    final service = MetaEventsService(enabled: false);
    await service.initialize();
    await service.login();
    await service.applicationSubmitted(12);
    expect(calls, isEmpty);
  });

  test('placeholder configuration cannot activate or log', () async {
    appId = '0';
    final service = MetaEventsService(enabled: true);
    await service.initialize();
    await service.registrationCompleted();
    expect(calls.map((c) => c.method), ['getApplicationId']);
  });

  test('events contain only intended parameters', () async {
    final service = MetaEventsService(enabled: true);
    await service.initialize();
    await service.registrationCompleted();
    await service.jobViewed(42);
    await service.jobSaved(42);
    await service.applicationSubmitted(42);
    final events = calls.where((c) => c.method == 'logEvent').toList();
    expect(events.map((c) => (c.arguments as Map)['name']), [
      'fb_mobile_complete_registration',
      'fb_mobile_content_view',
      'job_saved',
      'job_application_submitted',
    ]);
    expect((events.last.arguments as Map)['parameters'], {'job_id': '42'});
    expect(
      calls
          .singleWhere((c) => c.method == 'setAdvertiserIdCollectionEnabled')
          .arguments,
      false,
    );
  });

  test('extended funnel events use only allowlisted metadata', () async {
    final service = MetaEventsService(enabled: true);
    await service.initialize();
    await service.onboardingContinued();
    await service.jobsSearched(
      hasQuery: true,
      hasFilters: false,
      resultCount: 3,
    );
    await service.profileUpdated();
    await service.resumeUploaded();
    await service.resumeRemoved();
    await service.jobUnsaved(42);
    await service.applicationWithdrawn();
    await service.employerChatOpened(42);
    await service.employerDialerOpened(42);
    await service.employerReviewSubmitted();
    final events = calls.where((c) => c.method == 'logEvent').toList();
    expect(events.map((c) => (c.arguments as Map)['name']), [
      'onboarding_continued',
      'jobs_searched',
      'worker_profile_updated',
      'resume_uploaded',
      'resume_removed',
      'job_unsaved',
      'job_application_withdrawn',
      'employer_chat_opened',
      'employer_dialer_opened',
      'employer_review_submitted',
    ]);
    expect((events[1].arguments as Map)['parameters'], {
      'has_query': 1,
      'has_filters': 0,
      'result_count': 3,
    });
    for (final event in events) {
      final parameters = (event.arguments as Map)['parameters'] as Map?;
      expect(
        parameters?.keys ?? [],
        everyElement(
          isIn(['has_query', 'has_filters', 'result_count', 'job_id']),
        ),
      );
    }
  });

  test('SDK failures do not fail startup or successful actions', () async {
    final service = MetaEventsService(enabled: true);
    await service.initialize();
    fail = true;
    await expectLater(service.applicationSubmitted(42), completes);
    await expectLater(MetaEventsService(enabled: true).initialize(), completes);
  });
}
