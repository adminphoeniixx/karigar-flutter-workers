import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController([AuthService? service]) : _service = service ?? AuthService();
  final AuthService _service;
  bool loading = false;
  String? error;
  int cooldown = 30;
  AuthResult? result;
  Future<bool> sendOtp(String phone) => _run(() async { cooldown = await _service.sendOtp(phone); });
  Future<bool> verifyOtp(String phone, String otp) => _run(() async { result = await _service.verifyOtp(phone, otp); });
  Future<bool> _run(Future<void> Function() action) async {
    loading = true; error = null; notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      final messages = e.errors.values.expand((v) => v is List ? v : [v]);
      error = messages.isEmpty ? e.message : messages.first.toString();
      return false;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
