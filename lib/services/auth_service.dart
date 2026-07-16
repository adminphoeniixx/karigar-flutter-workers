import '../constants/api_constants.dart';
import '../models/api_models.dart';
import 'api_client.dart';

class AuthService {
  AuthService([ApiClient? client]) : _api = client ?? ApiClient.instance;
  final ApiClient _api;
  Future<int> sendOtp(String phone) async => ((await _api.post(ApiConstants.otpSend, {'phone': phone}))['cooldown'] as num?)?.toInt() ?? 30;
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final json = await _api.post(ApiConstants.otpVerify, {'phone': phone, 'otp': otp, 'role': 'worker', 'device_name': 'Karigar Worker App'});
    final result = AuthResult.fromJson(json);
    await _api.setToken(result.token);
    return result;
  }
  Future<UserModel> me() async => UserModel.fromJson(Map<String, dynamic>.from((await _api.get(ApiConstants.me))['user'] as Map));
  Future<MeModel> fetchMe() async => MeModel.fromJson(await _api.get(ApiConstants.me));
  Future<void> logout() async { try { await _api.post(ApiConstants.logout); } finally { await _api.setToken(null); } }
  Future<void> deleteAccount() async { await _api.delete(ApiConstants.account, {'confirm': true}); await _api.setToken(null); }
}
