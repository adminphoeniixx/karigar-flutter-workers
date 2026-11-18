import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/services/push_notification_service.dart';

void main() {
  test('both interview pushes route workers to Applications', () {
    for (final type in WorkerPushRoute.interviewTypes) {
      expect(
        WorkerPushRoute.fromData({
          'type': type,
          'application_id': 61,
          'url': '/worker/applications',
        }),
        WorkerPushDestination.applications,
      );
    }
  });

  test('unrelated notifications do not change the current tab', () {
    expect(WorkerPushRoute.fromData({'type': 'chat.message'}), isNull);
  });
}
