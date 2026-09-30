import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/models/api_models.dart';
import 'package:karigar_app/services/worker_api_service.dart';

class ProfileApi extends WorkerApiService {
  @override
  Future<WorkerProfileModel> profile() async => WorkerProfileModel({
    'education': '10th pass',
    'wage_type': ' DAILY ',
    'state': 'rajasthan',
    'city': 'Unlisted City',
  });
  @override
  Future<ReferenceData> reference() async => ReferenceData.fromJson({
    'education_levels': ['10th Pass', '10th pass', 'Graduate'],
    'wage_types': ['daily', 'monthly'],
    'states': ['Rajasthan', 'Rajasthan'],
  });
  @override
  Future<List<String>> cities(String state) async {
    expect(state, 'Rajasthan');
    return ['Jaipur', 'Jaipur'];
  }
}

void main() {
  test('normalizes duplicates and preserves missing saved values', () {
    final education = ProfileDropdownOptions([
      '10th Pass',
      '10th pass',
      ' 10th  Pass ',
    ], '10th pass');
    expect(education.items, ['10th Pass']);
    expect(education.selected, '10th Pass');
    final legacy = ProfileDropdownOptions(['Graduate'], 'Legacy education');
    expect(legacy.items, ['Graduate', 'Legacy education']);
    expect(legacy.selected, 'Legacy education');
    expect(ProfileDropdownOptions(['daily'], ' ').selected, isNull);
  });

  testWidgets(
    'saved API profile renders with exactly one matching dropdown item',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EditProfilePage(api: ProfileApi())),
      );
      await tester.pumpAndSettle();
      // Build the lazy form items, including education and location.
      await tester.drag(find.byType(ListView).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final field in tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      )) {
        expect(field.initialValue, isNotNull);
      }
      expect(find.text('10th Pass'), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Unlisted City'), findsWidgets);
    },
  );
}
