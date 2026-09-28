import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/services/api_client.dart';
import 'package:karigar_app/services/meta_events_service.dart';
import 'package:karigar_app/services/worker_api_service.dart';

class FakeWorkerClient implements ApiClient {
  bool fail = false;
  bool saved = false;

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (fail) throw ApiException('Rejected', statusCode: 422);
    return {'saved': saved};
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (fail) throw ApiException('Rejected', statusCode: 422);
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.oddbit.id/facebook_app_events');
  final names = <String>[];

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationId') return '123456789';
          if (call.method == 'logEvent') {
            names.add((call.arguments as Map)['name'] as String);
          }
          return null;
        });
    await MetaEventsService.instance.initialize();
    names.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'successful API actions emit matching events, including unsave',
    () async {
      final client = FakeWorkerClient();
      final api = WorkerApiService(client);
      await api.toggleSaved(42);
      client.saved = true;
      await api.toggleSaved(42);
      await api.withdraw(10);
      await api.reviewEmployer(10, 5, comment: 'Private review text');
      await api.apply(42, coverNote: 'Private cover note', expectedWage: 500);
      await Future<void>.delayed(Duration.zero);
      expect(names, [
        'job_unsaved',
        'job_saved',
        'job_application_withdrawn',
        'employer_review_submitted',
        'job_application_submitted',
      ]);
    },
  );

  test('failed API actions never emit success events', () async {
    final api = WorkerApiService(FakeWorkerClient()..fail = true);
    await expectLater(api.toggleSaved(42), throwsA(isA<ApiException>()));
    await expectLater(api.withdraw(10), throwsA(isA<ApiException>()));
    await expectLater(api.reviewEmployer(10, 5), throwsA(isA<ApiException>()));
    await expectLater(api.apply(42), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    expect(names, isEmpty);
  });
}
