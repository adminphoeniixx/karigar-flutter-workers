class ApiConstants {
  ApiConstants._();

  static const baseUrl =
      'https://projects-karigar.rmsiry.easypanel.host/api/v1';

  static const otpSend = '/auth/otp/send';
  static const otpVerify = '/auth/otp/verify';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const account = '/account';
  static const reference = '/reference';
  static const cities = '/reference/cities';
  static const jobCategories = '/reference/job-categories';
  static const workerProfile = '/worker/profile';
  static const avatar = '/worker/profile/avatar';
  static const availability = '/worker/availability';
  static const jobs = '/jobs';
  static const applications = '/worker/applications';
  static const saved = '/worker/saved';
  static const kyc = '/kyc';
  static const notifications = '/notifications';
  static const reviews = '/worker/reviews';
  static const dashboard = '/worker/dashboard';
  static const locale = '/locale';
  static const deviceTokens = '/device-tokens';
  static const resume = '/worker/resume';
  static const conversations = '/conversations';
  static const preferences = '/preferences';
  static const sessions = '/auth/sessions';

  static String job(int jobId) => '$jobs/$jobId';
  static String applyToJob(int jobId) => '$jobs/$jobId/apply';
  static String saveJob(int jobId) => '$jobs/$jobId/save';
  static String application(int applicationId) =>
      '/applications/$applicationId';
  static String reviewApplication(int applicationId) =>
      '/applications/$applicationId/review';
  static String readNotification(String notificationId) =>
      '$notifications/$notificationId/read';
  static const readAllNotifications = '$notifications/read-all';
  static String conversation(int id) => '$conversations/$id';
  static String conversationMessages(int id) => '$conversations/$id/messages';
  static String conversationRead(int id) => '$conversations/$id/read';
  static String session(String token) => '$sessions/$token';
}
