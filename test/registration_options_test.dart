import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/models/api_models.dart';
import 'package:karigar_app/services/worker_api_service.dart';

class ReferenceApi extends WorkerApiService {
  final requestedStates = <String>[];
  @override
  Future<ReferenceData> reference() async => ReferenceData.fromJson({
    'states': ['Rajasthan', 'Gujarat'],
    'skills': ['Solar Panel Installation', 'Mobile Repair'],
    'job_categories': ['Handmade Jewellery'],
    'spoken_languages': ['Hindi', 'Gujarati'],
  });
  @override
  Future<List<String>> cities(String state) async {
    requestedStates.add(state);
    return state == 'Rajasthan' ? ['Jaipur'] : ['Surat'];
  }
}

void main() {
  testWidgets('registration loads API skills and categories', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RegistrationPage(api: ReferenceApi())),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Solar Panel Installation'), findsOneWidget);
    expect(find.text('Mobile Repair'), findsOneWidget);
    await tester.tap(find.text('Select category'));
    await tester.pumpAndSettle();
    expect(find.text('Handmade Jewellery'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing state clears the previous city', (tester) async {
    final api = ReferenceApi();
    await tester.pumpWidget(MaterialApp(home: RegistrationPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select state'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rajasthan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select city'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jaipur').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rajasthan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gujarat').last);
    await tester.pumpAndSettle();
    expect(api.requestedStates, ['Rajasthan', 'Gujarat']);
    expect(find.text('Jaipur'), findsNothing);
    expect(find.text('Select city'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
