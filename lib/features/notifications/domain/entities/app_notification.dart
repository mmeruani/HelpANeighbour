class AppNotification {
  final String id;
  final String recipientUserId;
  final String title;
  final String body;
  final String targetRoute;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.targetRoute,
    required this.isRead,
    required this.createdAt,
  });
}
