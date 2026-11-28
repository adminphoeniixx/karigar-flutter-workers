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
        // The id brings that application to the top of the Applied tab.
        const OpenApplications(applicationId: 61),
      );
    }
  });

  test('a hire alert with its application id focuses that application', () {
    expect(
      WorkerPushRoute.fromData({
        'type': 'application.accepted',
        'application_id': '38',
      }),
      const OpenApplications(applicationId: 38),
    );
  });

  test('every application update opens Applications', () {
    for (final type in [
      'application.shortlisted',
      'application.accepted',
      'application.rejected',
      'interview.reminder_call',
    ]) {
      expect(
        WorkerPushRoute.fromData({'type': type}),
        WorkerPushDestination.applications,
        reason: type,
      );
    }
  });

  test('a new job alert and an invite open that job', () {
    // A push carries the id; an Alerts row keeps only the url.
    expect(
      WorkerPushRoute.fromData({'type': 'job.posted', 'job_listing_id': '170'}),
      const OpenJob(170),
    );
    expect(
      WorkerPushRoute.fromData({'type': 'job.posted', 'url': '/worker/jobs/171'}),
      const OpenJob(171),
    );
    expect(
      WorkerPushRoute.fromData({'type': 'job.invite', 'url': '/jobs/172'}),
      const OpenJob(172),
    );
  });

  test('a chat message opens its chat, and KYC opens KYC', () {
    expect(
      WorkerPushRoute.fromData({'type': 'chat.message', 'conversation_id': 7}),
      const OpenConversation(7),
    );
    expect(
      WorkerPushRoute.fromData({'type': 'chat.message', 'url': '/messages/8'}),
      const OpenConversation(8),
    );
    expect(
      WorkerPushRoute.fromData({'type': 'kyc.reviewed', 'url': '/kyc'}),
      WorkerPushDestination.kyc,
    );
  });

  test('unknown or incomplete notifications stay where they are', () {
    expect(WorkerPushRoute.fromData({'type': 'plan.reminder'}), isNull);
    expect(WorkerPushRoute.fromData({'type': 'chat.message'}), isNull);
    expect(WorkerPushRoute.fromData({'type': 'job.posted'}), isNull);
  });
}
