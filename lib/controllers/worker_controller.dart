import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/worker_api_service.dart';

class WorkerController extends ChangeNotifier {
  WorkerController([WorkerApiService? service]) : _service = service ?? WorkerApiService();
  final WorkerApiService _service;
  bool loading = false;
  String? error;
  WorkerProfileModel? profile;
  ReferenceData? reference;
  Map<String, dynamic>? dashboard;
  Future<bool> loadDashboard() => run(() async { dashboard = await _service.dashboard(); });
  Future<bool> loadProfile() => run(() async { profile = await _service.profile(); });
  Future<bool> loadReference() => run(() async { reference = await _service.reference(); });
  Future<bool> updateProfile(Map<String, dynamic> data) => run(() async { profile = await _service.updateProfile(data); });
  Future<bool> setAvailability(bool value) => run(() async { await _service.setAvailability(value); });
  Future<bool> run(Future<void> Function() operation) async { loading = true; error = null; notifyListeners(); try { await operation(); return true; } on ApiException catch (e) { error = e.message; return false; } finally { loading = false; notifyListeners(); } }
}
