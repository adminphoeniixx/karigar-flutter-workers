class UserModel {
  const UserModel({required this.id, required this.name, required this.phone, required this.role, this.locale = 'en', this.avatarUrl});
  final int id;
  final String name, phone, role, locale;
  final String? avatarUrl;
  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: (j['id'] as num).toInt(), name: j['name']?.toString() ?? '',
    phone: j['phone']?.toString() ?? '', role: j['role']?.toString() ?? '',
    locale: j['locale']?.toString() ?? 'en', avatarUrl: j['avatar_url']?.toString());
}

class AuthResult {
  const AuthResult({required this.token, required this.isNew, required this.needsRegistration, required this.user});
  final String token;
  final bool isNew, needsRegistration;
  final UserModel user;
  static bool _bool(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
    token: j['token'].toString(),
    isNew: _bool(j['is_new']),
    needsRegistration: _bool(j['needs_registration']),
    user: UserModel.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
  );
}

class ReferenceData {
  const ReferenceData({required this.states, required this.skills, required this.spokenLanguages, required this.educationLevels, required this.wageTypes, required this.jobCategories});
  final List<String> states, skills, spokenLanguages, educationLevels, wageTypes, jobCategories;
  factory ReferenceData.fromJson(Map<String, dynamic> j) {
    List<String> list(String key) => (j[key] as List? ?? []).map((e) => e.toString()).toList();
    return ReferenceData(states: list('states'), skills: list('skills'), spokenLanguages: list('spoken_languages'), educationLevels: list('education_levels'), wageTypes: list('wage_types'), jobCategories: list('job_categories'));
  }
}

class WorkerProfileModel {
  WorkerProfileModel(this.data);
  final Map<String, dynamic> data;
  factory WorkerProfileModel.fromJson(Map<String, dynamic> j) {
    final nested = j['data'];
    return WorkerProfileModel(
      nested is Map ? Map<String, dynamic>.from(nested) : j,
    );
  }
  String get name => data['name']?.toString() ?? '';
  int get completion => (data['completion'] as num?)?.toInt() ?? 0;
  bool get available => data['available'] == true;
}

class JobModel {
  JobModel(this.data);
  final Map<String, dynamic> data;
  factory JobModel.fromJson(Map<String, dynamic> j) => JobModel(j);
  int get id => (data['id'] as num).toInt();
  String get title => data['title']?.toString() ?? '';
}

class PageResult<T> {
  const PageResult({required this.items, required this.meta, required this.links});
  final List<T> items;
  final Map<String, dynamic> meta, links;
}

typedef Json = Map<String, dynamic>;

Json jsonMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
List<dynamic> jsonList(dynamic value) => value is List ? value : const [];
int jsonInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double jsonDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
bool jsonBool(dynamic value) => value == true || value == 1 || value == '1' || value == 'true';

String jobWageLabel(Json json) {
  final label = json['wage_label']?.toString().trim();
  if (label != null && label.isNotEmpty) return label;

  String? amount(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final number = num.tryParse(raw);
    if (number == null) return raw;
    final plain = number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
    return plain.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  final minimum = amount(json['wage_min']);
  final maximum = amount(json['wage_max']);
  final wageType = json['wage_type']?.toString().trim();
  final suffix = wageType == null || wageType.isEmpty ? '' : ' / $wageType';
  if (minimum == null && maximum == null) return 'Not disclosed';
  if (minimum == null) return '₹$maximum$suffix';
  if (maximum == null || minimum == maximum) return '₹$minimum$suffix';
  return '₹$minimum – ₹$maximum$suffix';
}

class RatingModel {
  const RatingModel({required this.average, required this.count});
  final double average;
  final int count;
  factory RatingModel.fromJson(Json json) => RatingModel(
    average: jsonDouble(json['average']),
    count: jsonInt(json['count']),
  );
}

class EmployerModel {
  const EmployerModel({required this.id, required this.name});
  final int id;
  final String name;
  factory EmployerModel.fromJson(Json json) => EmployerModel(
    id: jsonInt(json['id']),
    name: json['name']?.toString() ?? '',
  );
}

class ApiJobModel {
  const ApiJobModel({
    required this.id,
    required this.title,
    required this.category,
    required this.skills,
    required this.city,
    required this.state,
    required this.locationLabel,
    required this.wageLabel,
    required this.vacancies,
    required this.description,
    required this.createdAgo,
    required this.employer,
    this.latitude,
    this.longitude,
  });
  final int id, vacancies;
  final String title, category, city, state, locationLabel, wageLabel;
  final String description, createdAgo;
  final double? latitude, longitude;
  final List<String> skills;
  final EmployerModel employer;
  factory ApiJobModel.fromJson(Json json) => ApiJobModel(
    id: jsonInt(json['id']),
    title: json['title']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    skills: jsonList(json['skills']).map((e) => e.toString()).toList(),
    city: json['city']?.toString() ?? '',
    state: json['state']?.toString() ?? '',
    locationLabel: json['location_label']?.toString() ?? '',
    wageLabel: jobWageLabel(json),
    vacancies: jsonInt(json['vacancies']),
    description: json['description']?.toString() ?? '',
    createdAgo: json['created_ago']?.toString() ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    employer: EmployerModel.fromJson(jsonMap(json['employer'])),
  );
}

class PaginationModel {
  const PaginationModel({required this.currentPage, required this.lastPage, required this.total});
  final int currentPage, lastPage, total;
  factory PaginationModel.fromJson(Json json) => PaginationModel(
    currentPage: jsonInt(json['current_page']),
    lastPage: jsonInt(json['last_page']),
    total: jsonInt(json['total']),
  );
}

class JobPageModel {
  const JobPageModel({required this.jobs, required this.pagination});
  final List<ApiJobModel> jobs;
  final PaginationModel pagination;
  factory JobPageModel.fromJson(Json json) => JobPageModel(
    jobs: jsonList(json['data']).map((e) => ApiJobModel.fromJson(jsonMap(e))).toList(),
    pagination: PaginationModel.fromJson(jsonMap(json['meta'])),
  );
}

class JobDetailModel {
  const JobDetailModel({required this.job, required this.isSaved, required this.canApply, required this.employerRating, this.application, this.contactPhone});
  final ApiJobModel job;
  final bool isSaved, canApply;
  final ApplicationModel? application;
  final RatingModel employerRating;
  final String? contactPhone;
  factory JobDetailModel.fromJson(Json json) {
    final meta = jsonMap(json['meta']);
    final responseData = jsonMap(json['data']);
    final data = responseData['job'] is Map
        ? jsonMap(responseData['job'])
        : responseData;
    final employer = jsonMap(data['employer']);
    String? phone;
    for (final value in [
      data['contact_phone'],
      data['phone'],
      employer['contact_phone'],
      employer['phone'],
      meta['contact_phone'],
      meta['phone'],
      json['contact_phone'],
    ]) {
      final candidate = value?.toString().trim();
      if (candidate != null && candidate.isNotEmpty) {
        phone = candidate;
        break;
      }
    }
    return JobDetailModel(
      job: ApiJobModel.fromJson(data),
      isSaved: jsonBool(meta['is_saved']),
      canApply: jsonBool(meta['can_apply']),
      employerRating: RatingModel.fromJson(jsonMap(meta['employer_rating'])),
      contactPhone: phone,
      application: meta['application'] is Map
          ? ApplicationModel.fromJson(jsonMap(meta['application']))
          : null,
    );
  }
}

class ApplicationModel {
  const ApplicationModel({required this.id, required this.status, required this.statusLabel, required this.createdAgo, this.job, this.statusChangedAt, this.trackingSteps = const [], this.interview, this.offer});
  final int id;
  final String status, statusLabel, createdAgo;
  final ApiJobModel? job;
  final String? statusChangedAt;
  final List<TrackingStepModel> trackingSteps;
  final InterviewModel? interview;
  final OfferModel? offer;
  factory ApplicationModel.fromJson(Json json) => ApplicationModel(
    id: jsonInt(json['id']),
    status: json['status']?.toString() ?? '',
    statusLabel: json['status_label']?.toString() ?? json['status']?.toString() ?? '',
    createdAgo: json['created_ago']?.toString() ?? '',
    job: json['job'] is Map ? ApiJobModel.fromJson(jsonMap(json['job'])) : null,
    statusChangedAt: json['status_changed_at']?.toString(),
    trackingSteps: jsonList(json['tracking_steps'])
        .map((e) => TrackingStepModel.fromJson(jsonMap(e)))
        .toList(),
    interview: json['interview'] is Map ? InterviewModel.fromJson(jsonMap(json['interview'])) : null,
    offer: json['offer'] is Map ? OfferModel.fromJson(jsonMap(json['offer'])) : null,
  );
}

class InterviewModel {
  const InterviewModel({required this.atLabel, required this.mode, required this.note});
  final String atLabel, mode, note;
  factory InterviewModel.fromJson(Json j) => InterviewModel(atLabel: j['at_label']?.toString() ?? '', mode: j['mode']?.toString() ?? '', note: j['note']?.toString() ?? '');
}

class OfferModel {
  const OfferModel({required this.wage, required this.startDate, required this.message});
  final double wage;
  final String startDate, message;
  factory OfferModel.fromJson(Json j) => OfferModel(wage: jsonDouble(j['wage']), startDate: j['start_date']?.toString() ?? '', message: j['message']?.toString() ?? '');
}

class ResumeModel {
  const ResumeModel({required this.name, required this.uploadedAgo, required this.characters, required this.maxCharacters});
  final String name, uploadedAgo;
  final int characters, maxCharacters;
  factory ResumeModel.fromJson(Json j) => ResumeModel(name: j['name']?.toString() ?? 'Resume.pdf', uploadedAgo: j['uploaded_ago']?.toString() ?? '', characters: jsonInt(j['characters']), maxCharacters: jsonInt(j['max_characters']));
}

class PreferencesModel {
  const PreferencesModel({required this.theme, required this.jobAlerts, required this.messageAlerts});
  final String theme;
  final bool jobAlerts, messageAlerts;
  factory PreferencesModel.fromJson(Json j) => PreferencesModel(theme: j['theme']?.toString() ?? 'system', jobAlerts: jsonBool(j['job_alerts']), messageAlerts: jsonBool(j['message_alerts']));
}

class ConversationModel {
  const ConversationModel({required this.id, required this.otherParty, required this.unread, required this.lastMessageAt, this.job});
  final int id, unread;
  final String otherParty, lastMessageAt;
  final ApiJobModel? job;
  factory ConversationModel.fromJson(Json j) => ConversationModel(
    id: jsonInt(j['id']), otherParty: jsonMap(j['other_party'])['name']?.toString() ?? 'Employer',
    unread: jsonInt(j['unread']), lastMessageAt: j['last_message_at']?.toString() ?? '',
    job: j['job'] is Map ? ApiJobModel.fromJson(jsonMap(j['job'])) : null,
  );
}

class MessageModel {
  const MessageModel({required this.id, required this.body, required this.mine, required this.createdAt});
  final int id;
  final String body, createdAt;
  final bool mine;
  factory MessageModel.fromJson(Json j, {int? currentUserId}) {
    final sender = jsonMap(j['sender']);
    final explicitMine = j.containsKey('mine')
        ? jsonBool(j['mine'])
        : j.containsKey('is_mine')
            ? jsonBool(j['is_mine'])
            : null;
    final senderRole = (sender['role'] ?? j['sender_role'] ?? j['sender_type'])
        ?.toString()
        .toLowerCase();
    final senderId = jsonInt(
      j['sender_id'] ?? j['user_id'] ?? sender['id'],
    );
    final sentByCurrentUser = currentUserId != null &&
        senderId != 0 &&
        senderId == currentUserId;
    return MessageModel(
      id: jsonInt(j['id']),
      body: j['body']?.toString() ?? '',
      mine: sentByCurrentUser || (explicitMine ?? senderRole == 'worker'),
      createdAt: j['created_at']?.toString() ?? '',
    );
  }

  MessageModel asMine() =>
      MessageModel(id: id, body: body, mine: true, createdAt: createdAt);
}

class ConversationPageModel {
  const ConversationPageModel({required this.conversations, required this.unreadTotal});
  final List<ConversationModel> conversations;
  final int unreadTotal;
  factory ConversationPageModel.fromJson(Json j) => ConversationPageModel(
    conversations: jsonList(j['conversations'] ?? j['data']).map((e) => ConversationModel.fromJson(jsonMap(e))).toList(),
    unreadTotal: jsonInt(j['unread_total']),
  );
}

class ConversationDetailModel {
  const ConversationDetailModel({required this.conversation, required this.messages});
  final ConversationModel conversation;
  final List<MessageModel> messages;
  factory ConversationDetailModel.fromJson(Json j, {int? currentUserId}) =>
      ConversationDetailModel(
    conversation: ConversationModel.fromJson(jsonMap(j['conversation'])),
    messages: jsonList(j['messages'] is Map ? jsonMap(j['messages'])['data'] : j['messages'])
        .map((e) => MessageModel.fromJson(
              jsonMap(e),
              currentUserId: currentUserId,
            ))
        .toList(),
  );
}

class SessionModel {
  const SessionModel({required this.id, required this.device, required this.current, required this.lastUsedAgo});
  final String id, device, lastUsedAgo;
  final bool current;
  factory SessionModel.fromJson(Json j) => SessionModel(id: j['id']?.toString() ?? '', device: j['device']?.toString() ?? 'Unknown device', current: jsonBool(j['current']), lastUsedAgo: j['last_used_ago']?.toString() ?? '');
}

class TrackingStepModel {
  const TrackingStepModel({required this.key, required this.state, this.at, this.result});
  final String key, state;
  final String? at, result;
  factory TrackingStepModel.fromJson(Json json) => TrackingStepModel(
    key: json['key']?.toString() ?? '',
    state: json['state']?.toString() ?? 'upcoming',
    at: json['at']?.toString(),
    result: json['result']?.toString(),
  );
}

class ApplicationPageModel {
  const ApplicationPageModel({required this.applications, required this.pagination});
  final List<ApplicationModel> applications;
  final PaginationModel pagination;
  factory ApplicationPageModel.fromJson(Json json) => ApplicationPageModel(
    applications: jsonList(json['data']).map((e) => ApplicationModel.fromJson(jsonMap(e))).toList(),
    pagination: PaginationModel.fromJson(jsonMap(json['meta'])),
  );
}

class KycModel {
  const KycModel({required this.status, required this.maskedPan, required this.maskedAadhaar, this.remarks});
  final String status, maskedPan, maskedAadhaar;
  final String? remarks;
  factory KycModel.fromJson(Json json) => KycModel(
    status: json['status']?.toString() ?? 'not_submitted',
    maskedPan: json['masked_pan']?.toString() ?? '',
    maskedAadhaar: json['masked_aadhaar']?.toString() ?? '',
    remarks: json['remarks']?.toString(),
  );
}

class NotificationModel {
  const NotificationModel({required this.id, required this.type, required this.message, required this.url, required this.read, required this.createdAgo});
  final String id, type, message, url, createdAgo;
  final bool read;
  factory NotificationModel.fromJson(Json json) => NotificationModel(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    read: jsonBool(json['read']),
    createdAgo: json['created_ago']?.toString() ?? '',
  );
}

class ReviewModel {
  const ReviewModel({required this.id, required this.rating, required this.comment, required this.createdAgo, required this.reviewer});
  final int id, rating;
  final String comment, createdAgo;
  final EmployerModel reviewer;
  factory ReviewModel.fromJson(Json json) => ReviewModel(
    id: jsonInt(json['id']), rating: jsonInt(json['rating']),
    comment: json['comment']?.toString() ?? '',
    createdAgo: json['created_ago']?.toString() ?? '',
    reviewer: EmployerModel.fromJson(jsonMap(json['reviewer'] ?? json['employer'])),
  );
}

class DashboardStatsModel {
  const DashboardStatsModel({required this.availableJobs, required this.applications, required this.savedJobs, required this.kycStatusLabel, required this.profileCompletion, required this.unreadNotifications});
  final int availableJobs, applications, savedJobs, profileCompletion, unreadNotifications;
  final String kycStatusLabel;
  factory DashboardStatsModel.fromJson(Json json) => DashboardStatsModel(
    availableJobs: jsonInt(json['available_jobs']), applications: jsonInt(json['applications']),
    savedJobs: jsonInt(json['saved_jobs']), kycStatusLabel: json['kyc_status_label']?.toString() ?? '',
    profileCompletion: jsonInt(json['profile_completion']), unreadNotifications: jsonInt(json['unread_notifications']),
  );
}

class DashboardModel {
  const DashboardModel({required this.greeting, required this.profile, required this.stats, required this.latestJobs});
  final String greeting;
  final WorkerProfileModel profile;
  final DashboardStatsModel stats;
  final List<ApiJobModel> latestJobs;
  factory DashboardModel.fromJson(Json json) {
    final latest = jsonMap(json['latest_jobs']);
    return DashboardModel(
      greeting: json['greeting']?.toString() ?? '',
      profile: WorkerProfileModel.fromJson(jsonMap(json['profile'])),
      stats: DashboardStatsModel.fromJson(jsonMap(json['stats'])),
      latestJobs: jsonList(latest['data']).map((e) => ApiJobModel.fromJson(jsonMap(e))).toList(),
    );
  }
}

class MeModel {
  const MeModel({required this.user, required this.unreadNotifications});
  final UserModel user;
  final int unreadNotifications;
  factory MeModel.fromJson(Json json) => MeModel(
    user: UserModel.fromJson(jsonMap(json['user'])),
    unreadNotifications: jsonInt(json['unread_notifications']),
  );
}

class SavedJobModel {
  const SavedJobModel({required this.id, required this.job});
  final int id;
  final ApiJobModel job;
  factory SavedJobModel.fromJson(Json json) => SavedJobModel(
    id: jsonInt(json['id']),
    job: ApiJobModel.fromJson(jsonMap(json['job'] ?? json)),
  );
}

class NotificationPageModel {
  const NotificationPageModel({required this.notifications, required this.unread, required this.pagination});
  final List<NotificationModel> notifications;
  final int unread;
  final PaginationModel pagination;
  factory NotificationPageModel.fromJson(Json json) {
    final page = jsonMap(json['notifications']);
    return NotificationPageModel(
      notifications: jsonList(page['data']).map((e) => NotificationModel.fromJson(jsonMap(e))).toList(),
      unread: jsonInt(json['unread']),
      pagination: PaginationModel.fromJson(jsonMap(page['meta'])),
    );
  }
}

class ReviewPageModel {
  const ReviewPageModel({required this.reviews, required this.summary, required this.pagination});
  final List<ReviewModel> reviews;
  final RatingModel summary;
  final PaginationModel pagination;
  factory ReviewPageModel.fromJson(Json json) {
    final page = json['reviews'] is Map ? jsonMap(json['reviews']) : json;
    return ReviewPageModel(
      reviews: jsonList(page['data']).map((e) => ReviewModel.fromJson(jsonMap(e))).toList(),
      summary: RatingModel.fromJson(jsonMap(json['summary'])),
      pagination: PaginationModel.fromJson(jsonMap(page['meta'])),
    );
  }
}

class LocaleModel {
  const LocaleModel({required this.locale, required this.supported});
  final String locale;
  final List<dynamic> supported;
  factory LocaleModel.fromJson(Json json) => LocaleModel(
    locale: json['locale']?.toString() ?? 'en',
    supported: jsonList(json['supported']),
  );
}
