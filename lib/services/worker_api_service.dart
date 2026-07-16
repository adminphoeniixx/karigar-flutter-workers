import 'dart:io';
import '../constants/api_constants.dart';
import '../models/api_models.dart';
import 'api_client.dart';

class WorkerApiService {
  WorkerApiService([ApiClient? client]) : _api = client ?? ApiClient.instance;
  final ApiClient _api;
  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<ReferenceData> reference() async =>
      ReferenceData.fromJson(_payload(await _api.get(ApiConstants.reference)));
  Future<List<String>> cities(String state) async =>
      (_payload(await _api.get(ApiConstants.cities, query: {'state': state}))['cities'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
  Future<List<String>> jobCategories() async =>
      ((_payload(await _api.get(ApiConstants.jobCategories)))['job_categories'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
  Future<WorkerProfileModel> profile() async =>
      WorkerProfileModel.fromJson(_payload(await _api.get(ApiConstants.workerProfile)));
  Future<WorkerProfileModel> updateProfile(Map<String, dynamic> values) async =>
      WorkerProfileModel.fromJson(_payload(await _api.patch(ApiConstants.workerProfile, values)));
  Future<String?> uploadAvatar(File image) async => (await _api.multipart(ApiConstants.avatar, {}, {'avatar': image}))['avatar_url']?.toString();
  Future<bool> setAvailability(bool value) async => (await _api.patch(ApiConstants.availability, {'available': value}))['available'] == true;
  Future<Map<String, dynamic>> dashboard() async =>
      _payload(await _api.get(ApiConstants.dashboard));
  Future<DashboardModel> fetchDashboard() async =>
      DashboardModel.fromJson(await dashboard());
  Future<Map<String, dynamic>> jobs({Map<String, dynamic>? filters, int? page}) =>
      _api.get(ApiConstants.jobs, query: {
        ...?filters,
        if (page != null) 'page': page,
      });
  Future<JobPageModel> fetchJobs({Map<String, dynamic>? filters, int? page}) async =>
      JobPageModel.fromJson(await jobs(filters: filters, page: page));
  Future<Map<String, dynamic>> job(int id) => _api.get(ApiConstants.job(id));
  Future<JobDetailModel> fetchJob(int id) async =>
      JobDetailModel.fromJson(await job(id));
  Future<Map<String, dynamic>> apply(int jobId, {String? coverNote, num? expectedWage}) => _api.post(ApiConstants.applyToJob(jobId), {if (coverNote != null) 'cover_note': coverNote, if (expectedWage != null) 'expected_wage': expectedWage});
  Future<Map<String, dynamic>> applications({String? status, int? page}) => _api.get(ApiConstants.applications, query: {if (status != null && status.isNotEmpty) 'status': status, if (page != null) 'page': page});
  Future<ApplicationPageModel> fetchApplications({String? status, int? page}) async =>
      ApplicationPageModel.fromJson(await applications(status: status, page: page));
  Future<void> withdraw(int applicationId) async {
    await _api.delete(ApiConstants.application(applicationId));
  }
  Future<Map<String, dynamic>> savedJobs({int? page}) =>
      _api.get(ApiConstants.saved, query: {if (page != null) 'page': page});
  Future<List<SavedJobModel>> fetchSavedJobs({int? page}) async =>
      jsonList((await savedJobs(page: page))['data'])
          .map((e) => SavedJobModel.fromJson(jsonMap(e)))
          .toList();
  Future<bool> toggleSaved(int jobId) async => (await _api.post(ApiConstants.saveJob(jobId)))['saved'] == true;
  Future<Map<String, dynamic>> kyc() => _api.get(ApiConstants.kyc);
  Future<KycModel?> fetchKyc() async {
    final response = await kyc();
    final value = response['kyc'];
    return value is Map ? KycModel.fromJson(jsonMap(value)) : null;
  }
  Future<Map<String, dynamic>> submitKyc({required String pan, required String aadhaar, required File panDoc, required File aadhaarDoc}) => _api.multipart(ApiConstants.kyc, {'pan_number': pan, 'aadhaar_number': aadhaar}, {'pan_doc': panDoc, 'aadhaar_doc': aadhaarDoc});
  Future<Map<String, dynamic>> notifications({int? page}) =>
      _api.get(ApiConstants.notifications, query: {if (page != null) 'page': page});
  Future<List<NotificationModel>> fetchNotifications({int? page}) async {
    final response = await notifications(page: page);
    final paginated = jsonMap(response['notifications']);
    return jsonList(paginated['data'])
        .map((e) => NotificationModel.fromJson(jsonMap(e)))
        .toList();
  }
  Future<NotificationPageModel> fetchNotificationPage({int? page}) async =>
      NotificationPageModel.fromJson(await notifications(page: page));
  Future<int> readNotification(String id) async => ((await _api.post(ApiConstants.readNotification(id)))['unread'] as num?)?.toInt() ?? 0;
  Future<int> readAllNotifications() async => ((await _api.post(ApiConstants.readAllNotifications))['unread'] as num?)?.toInt() ?? 0;
  Future<Map<String, dynamic>> reviews({int? page}) =>
      _api.get(ApiConstants.reviews, query: {if (page != null) 'page': page});
  Future<List<ReviewModel>> fetchReviews({int? page}) async {
    final response = await reviews(page: page);
    final paginated = response['reviews'] is Map
        ? jsonMap(response['reviews'])
        : response;
    return jsonList(paginated['data'])
        .map((e) => ReviewModel.fromJson(jsonMap(e)))
        .toList();
  }
  Future<ReviewPageModel> fetchReviewPage({int? page}) async =>
      ReviewPageModel.fromJson(await reviews(page: page));
  Future<void> reviewEmployer(int applicationId, int rating, {String? comment}) async {
    await _api.post(ApiConstants.reviewApplication(applicationId), {'rating': rating, if (comment != null) 'comment': comment});
  }
  Future<String> setLocale(String locale) async => (await _api.post(ApiConstants.locale, {'locale': locale}))['locale']?.toString() ?? locale;
  Future<LocaleModel> updateLocale(String locale) async =>
      LocaleModel.fromJson(await _api.post(ApiConstants.locale, {'locale': locale}));
}
