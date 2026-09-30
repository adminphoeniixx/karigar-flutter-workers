import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/models/api_models.dart';

void main() {
  test('only worker accounts qualify for worker access', () {
    UserModel user(String role) => UserModel.fromJson({'id': 1, 'role': role});
    expect(user('worker').isWorker, isTrue);
    expect(user(' Worker ').isWorker, isTrue);
    for (final role in ['employer', 'admin', '']) {
      expect(user(role).isWorker, isFalse);
    }
  });
}
