import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/services/api_client.dart';
import 'package:karigar_app/services/worker_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> message(int id, String body) => {
  'id': id,
  'body': body,
  'sender_id': 50,
  'created_at': '2026-11-26T10:00:00Z',
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'secret'});
    await ApiClient.instance.initialize();
    WorkerApiService.forgetCurrentUser();
    selectedLanguageCode.value = 'en';
    appLocale.value = const Locale('en');
  });
  tearDown(() {
    selectedLanguageCode.value = 'hi';
    appLocale.value = const Locale('hi');
  });

  testWidgets('an open chat picks up a new reply without a push', (
    tester,
  ) async {
    var meCalls = 0;
    var replies = [message(1, 'Can you join tomorrow?')];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        meCalls++;
        return http.Response(
          jsonEncode({
            'user': {'id': 9, 'name': 'Test Worker', 'role': 'worker'},
          }),
          200,
        );
      }
      final page = request.url.queryParameters['page'] ?? '1';
      return http.Response(
        jsonEncode({
          'conversation': {
            'id': 7,
            'other_party': {'name': 'Jaipur Looms'},
          },
          'messages': page == '2' ? [message(0, 'Hello from last week')] : replies,
          'meta': {'current_page': int.parse(page), 'last_page': 2},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConversationPage(7)));
      await tester.pumpAndSettle();
      expect(find.text('Can you join tomorrow?'), findsOneWidget);

      replies = [...replies, message(2, 'Yes, I will come at 10.')];
      await tester.pump(ConversationPage.pollEvery);
      await tester.pumpAndSettle();
      expect(find.text('Yes, I will come at 10.'), findsOneWidget);
      // The worker's own id is asked for once, not on every refresh.
      expect(meCalls, 1);

      await tester.tap(find.text('Older messages'));
      await tester.pumpAndSettle();
      expect(find.text('Hello from last week'), findsOneWidget);
      expect(find.text('Can you join tomorrow?'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, () => client);
  });
}
