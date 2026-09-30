import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:karigar_app/services/india_locations.dart';

class TestCityBundle extends CachingAssetBundle {
  TestCityBundle(this.content);
  final String? content;
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (content == null) throw StateError('Asset missing');
    return content!;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('missing, empty and malformed city assets do not throw', () async {
    for (final content in [null, '', 'not json', '[]', '{"Rajasthan": 123}']) {
      expect(await IndiaLocations.readBundle(TestCityBundle(content)), isEmpty);
    }
    expect(
      await IndiaLocations.readBundle(
        TestCityBundle('{"Rajasthan":["Jaipur"]}'),
      ),
      {
        'Rajasthan': ['Jaipur'],
      },
    );
  });

  test(
    'bundled India reference includes all states and state-specific cities',
    () async {
      expect(await IndiaLocations.states(), hasLength(36));
      final rajasthan = await IndiaLocations.cities('Rajasthan');
      expect(rajasthan.length, greaterThan(150));
      expect(rajasthan, contains('Jaipur'));
      expect(rajasthan, isNot(contains('Surat')));
      expect(await IndiaLocations.cities('gujarat'), contains('Surat'));
    },
  );
  test('server spelling takes precedence without duplicate cities', () {
    expect(IndiaLocations.merge(['Jaipur', ' Surat '], ['jaipur', 'Ajmer']), [
      'Ajmer',
      'Jaipur',
      'Surat',
    ]);
  });
}
