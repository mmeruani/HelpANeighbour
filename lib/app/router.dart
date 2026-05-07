import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/community/presentation/pages/communities_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/requests/presentation/pages/community_requests_page.dart';
import '../features/requests/presentation/pages/completed_services_page.dart';
import '../features/requests/presentation/pages/create_request_page.dart';
import '../features/requests/presentation/pages/customer_history_page.dart';
import '../features/requests/presentation/pages/executor_history_page.dart';
import '../features/requests/presentation/pages/edit_request_page.dart';
import '../features/requests/presentation/pages/request_details_page.dart';
import '../features/reviews/presentation/pages/leave_review_page.dart';
import '../features/reviews/presentation/pages/user_reviews_page.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/profile/presentation/pages/edit_profile_page.dart';
import '../features/profile/presentation/pages/notofication_settings_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepository.authState()),
    redirect: (context, state) {
      final isAuthenticated =
          ref.read(firebaseAuthProvider).currentUser != null;
      final location = state.matchedLocation;
      final isAuthRoute =
          location == '/login' ||
          location == '/register' ||
          location == '/splash';

      if (location == '/splash') {
        return isAuthenticated ? '/communities' : '/login';
      }

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (location == '/login' ||
          location == '/register' ||
          location == '/splash') {
        return '/communities';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/profile/reviews/:userId',
        builder: (context, state) =>
            UserReviewsPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/profile/completed-services',
        builder: (context, state) => const CompletedServicesPage(),
      ),
      GoRoute(
        path: '/profile/customer-history',
        builder: (context, state) => const CustomerHistoryPage(),
      ),
      GoRoute(
        path: '/profile/executor-history',
        builder: (context, state) => const ExecutorHistoryPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/communities',
        builder: (context, state) => const CommunitiesPage(),
      ),
      GoRoute(
        path: '/communities/:communityId/requests',
        builder: (context, state) => CommunityRequestsPage(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/communities/:communityId/requests/create',
        builder: (context, state) => CreateRequestPage(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/requests/:requestId',
        builder: (context, state) =>
            RequestDetailsPage(requestId: state.pathParameters['requestId']!),
      ),
      GoRoute(
        path: '/requests/:requestId/edit',
        builder: (context, state) =>
            EditRequestPage(requestId: state.pathParameters['requestId']!),
      ),
      GoRoute(
        path: '/requests/:requestId/review/:executorId',
        builder: (context, state) => LeaveReviewPage(
          requestId: state.pathParameters['requestId']!,
          executorId: state.pathParameters['executorId']!,
        ),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
