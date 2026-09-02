class AppRoutes {
  static const String splash = '/';
  static const String landing = '/landing';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String courses = '/courses';
  static const String courseDetail = '/courses/:id';
  static const String sectionLessons = '/courses/:id/sections/:sectionId';
  static const String lesson = '/lesson/:lessonId';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String placementDrives = '/placement-drives';
  static const String calendar = '/calendar';
  static const String assignments = '/assignments';
  static const String exams = '/exams';
  static const String certificates = '/certificates';
  static const String resumeBuilder = '/resume-builder';
  static const String discussion = '/discussion/:lessonId';
  static const String search = '/search';
  static const String subscription = '/subscription';
  static const String paymentHistory = '/payment-history';
  static const String attendance = '/attendance';
  static const String feedback = '/feedback';
  static const String interviewHistory = '/interview-history';
  static const String bookmarks = '/bookmarks';
  static const String leaderboard = '/leaderboard';
  static const String qa = '/qa';
  static const String companyQuestions = '/company-questions';
  static const String supportRequest = '/support-request';
  static const String inAppBrowser = '/browser';
  /// In-app question paper; :type is 'assignments' or 'exams'.
  static const String assessmentPaper = '/assessment-paper/:type/:id';
  static const String mentorChat = '/chat/:mentorId';
  static const String notes = '/notes/:lessonId';
  static const String payment = '/payment/:planId';
  /// The payment route with its plan-id parameter filled in — use this to
  /// navigate ([payment] is a route *pattern*, not a navigable path).
  static String paymentFor(int planId) => '/payment/$planId';
}