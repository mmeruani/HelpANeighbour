import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/core/config/service_categories.dart';
import 'package:help_a_neighbour/features/profile/domain/entities/notification_settings.dart';

void main() {
  group('NotificationSettings.defaults', () {
    test('enables all notification switches by default', () {
      final settings = NotificationSettings.defaults();

      expect(settings.newRequestsInCommunities, isTrue);
      expect(settings.responsesToMyRequests, isTrue);
      expect(settings.selectedAsExecutor, isTrue);
      expect(settings.newReviews, isTrue);
    });

    test('selects all service categories by default', () {
      final settings = NotificationSettings.defaults();

      expect(settings.subscribedCategoryIds, ServiceCategories.titles);
      expect(settings.subscribedCategoryIds, isNotEmpty);
    });
  });
}
