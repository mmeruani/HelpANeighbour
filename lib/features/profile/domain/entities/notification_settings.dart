import '../../../../core/config/service_categories.dart';

class NotificationSettings {
  final bool newRequestsInCommunities;
  final bool responsesToMyRequests;
  final bool selectedAsExecutor;
  final bool newReviews;
  final List<String> subscribedCategoryIds;

  const NotificationSettings({
    required this.newRequestsInCommunities,
    required this.responsesToMyRequests,
    required this.selectedAsExecutor,
    required this.newReviews,
    required this.subscribedCategoryIds,
  });

  factory NotificationSettings.defaults() => NotificationSettings(
    newRequestsInCommunities: true,
    responsesToMyRequests: true,
    selectedAsExecutor: true,
    newReviews: true,
    subscribedCategoryIds: ServiceCategories.titles,
  );
}
