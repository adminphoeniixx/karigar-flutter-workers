import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';

void main() {
  test('formatKm drops ".0" and keeps one decimal only under 10 km', () {
    expect(formatKm(923.0), '923');
    expect(formatKm(923.4), '923');
    expect(formatKm(1832.2), '1,832');
    expect(formatKm(12.6), '13');
    expect(formatKm(2.5), '2.5');
    expect(formatKm(3.0), '3');
    expect(formatKm(0.4), '0.4');
  });
}
