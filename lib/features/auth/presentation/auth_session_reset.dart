import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/presentation/controllers/community_controller.dart';
import '../../notifications/presentation/controllers/notification_controller.dart';
import '../../profile/presentation/controllers/profile_controller.dart';
import '../../requests/presentation/controllers/request_controller.dart';
import '../../reviews/presentation/controllers/review_controller.dart';

void resetUserScopedProviders(WidgetRef ref) {
  ref.invalidate(profileControllerProvider);
  ref.invalidate(communityControllerProvider);
  ref.invalidate(requestControllerProvider);
  ref.invalidate(notificationControllerProvider);
  ref.invalidate(reviewControllerProvider);
}
