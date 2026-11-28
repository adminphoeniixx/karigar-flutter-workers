import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:karigar_app/main.dart';
import 'package:karigar_app/services/api_client.dart';
import 'package:karigar_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('no connection reads as "no internet", however Android reports it', () {
    final direct = transportError(const SocketException('Failed host lookup'));
    final wrapped = transportError(
      http.ClientException(
        "SocketException: Failed host lookup: 'superkarigar.com'",
      ),
    );
    expect(direct.message, noInternetMessage);
    expect(wrapped.message, noInternetMessage);
    expect(wrapped.statusCode, 0);
  });

  test('a request that takes too long says so', () {
    expect(
      transportError(TimeoutException('slow')).message,
      slowServerMessage,
    );
  });

  test('offer pay reads as rupees, the Indian way', () {
    expect(formatRupees(15000), '₹15,000');
    expect(formatRupees(150000), '₹1,50,000');
    expect(formatRupees(999), '₹999');
    expect(formatRupees(15000.5), '₹15,000.50');
  });

  test('logout signs out on this phone even when the server cannot be told', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'secret'});
    await ApiClient.instance.initialize();
    expect(ApiClient.instance.isAuthenticated, isTrue);

    // Tests have no network: the logout request fails.
    await AuthService().logout();

    expect(ApiClient.instance.isAuthenticated, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });
}
