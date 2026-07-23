import '../constants/api_constants.dart';
import 'api_client.dart';

enum DevicePlatform {
  android('android'),
  ios('ios');

  const DevicePlatform(this.apiValue);

  final String apiValue;
}

/// Registers push-notification tokens for the authenticated user.
class DeviceTokenService {
  DeviceTokenService([ApiClient? client])
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {
    final normalizedToken = _validateToken(token);
    await _api.post(ApiConstants.deviceTokens, {
      'token': normalizedToken,
      'platform': platform.apiValue,
    });
  }

  Future<void> unregister(String token) async {
    final normalizedToken = _validateToken(token);
    await _api.delete(ApiConstants.deviceTokens, {'token': normalizedToken});
  }

  String _validateToken(String token) {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Device token cannot be empty.');
    }
    return normalizedToken;
  }
}
