import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/models/api_models.dart';
import 'package:karigar_app/services/worker_api_service.dart';

class EditableProfileApi extends WorkerApiService {
  Map<String, dynamic>? saved;
  @override
  Future<WorkerProfileModel> profile() async => WorkerProfileModel({
    'name': 'Aman',
    'expected_wage': 800,
    'wage_type': 'daily',
    'skills': ['Plumbing'],
    'spoken_languages': ['Hindi'],
    'address': '12, Main Road, 302001',
    'state': 'Rajasthan',
    'city': 'Jaipur',
  });
  @override
  Future<ReferenceData> reference() async => ReferenceData.fromJson({
    'skills': ['Plumbing', 'Carpentry'],
    'spoken_languages': ['Hindi', 'English'],
    'states': ['Rajasthan', 'Gujarat'],
  });
  @override
  Future<List<String>> cities(String state) async =>
      state == 'Gujarat' ? ['Surat'] : ['Jaipur'];
  @override
  Future<WorkerProfileModel> updateProfile(Map<String, dynamic> values) async {
    saved = values;
    return WorkerProfileModel(values);
  }
}

void main() {
  testWidgets('skills languages and complete address are editable and saved', (
    tester,
  ) async {
    final api = EditableProfileApi();
    await tester.pumpWidget(MaterialApp(home: EditProfilePage(api: api)));
    await tester.pumpAndSettle();
    Future<void> reveal(Key key) async {
      await tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await reveal(const ValueKey('edit-skills'));
    await tester.tap(find.byKey(const ValueKey('edit-skills')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Carpentry'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Plumbing'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await reveal(const ValueKey('edit-languages'));
    await tester.tap(find.byKey(const ValueKey('edit-languages')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'English'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await reveal(const ValueKey('profile-address'));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-address')))
          .controller!
          .text,
      '12, Main Road, 302001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-address')),
      '24, New Road, Near School, 395001',
    );
    await reveal(const ValueKey('edit-state'));
    await tester.tap(find.byKey(const ValueKey('edit-state')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gujarat').last);
    await tester.pumpAndSettle();
    expect(find.text('Jaipur'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surat').last);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 3; i++) {
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();
    expect(api.saved?['skills'], ['Carpentry']);
    expect(api.saved?['expected_wage'], 20800);
    expect(api.saved?['wage_type'], 'monthly');
    expect(api.saved?['spoken_languages'], ['Hindi', 'English']);
    expect(api.saved?['address'], '24, New Road, Near School, 395001');
    expect(api.saved?['state'], 'Gujarat');
    expect(api.saved?['city'], 'Surat');
    expect(tester.takeException(), isNull);
  });

  test('full address includes street, city and state without blanks', () {
    expect(
      WorkerProfileModel({
        'address': '12 Main Road',
        'city': 'Jaipur',
        'state': 'Rajasthan',
      }).fullAddress,
      '12 Main Road, Jaipur, Rajasthan',
    );
  });
}
