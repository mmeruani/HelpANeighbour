import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/service_categories.dart';
import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/service_category_controls.dart';
import '../../domain/entities/notification_settings.dart';
import '../controllers/profile_controller.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  NotificationSettings? _draft;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _draft ??= profile.notificationSettings;
    final draft = _draft!;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppPageHeader(
            title: 'Настройки уведомлений',
            subtitle:
                'Выберите только важные для вас события, чтобы приложение оставалось полезным и не перегружало вниманием.',
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              children: [
                _NotificationToggleTile(
                  value: draft.newRequestsInCommunities,
                  title: 'Новые запросы в сообществах',
                  onChanged: (value) {
                    setState(() {
                      _draft = NotificationSettings(
                        newRequestsInCommunities: value,
                        responsesToMyRequests: draft.responsesToMyRequests,
                        selectedAsExecutor: draft.selectedAsExecutor,
                        newReviews: draft.newReviews,
                        subscribedCategoryIds: value
                            ? draft.subscribedCategoryIds.isEmpty
                                  ? ServiceCategories.titles
                                  : draft.subscribedCategoryIds
                            : const [],
                      );
                    });
                  },
                ),
                _NotificationToggleTile(
                  value: draft.responsesToMyRequests,
                  title: 'Отклики на мои запросы',
                  onChanged: (value) {
                    setState(() {
                      _draft = NotificationSettings(
                        newRequestsInCommunities:
                            draft.newRequestsInCommunities,
                        responsesToMyRequests: value,
                        selectedAsExecutor: draft.selectedAsExecutor,
                        newReviews: draft.newReviews,
                        subscribedCategoryIds: draft.subscribedCategoryIds,
                      );
                    });
                  },
                ),
                _NotificationToggleTile(
                  value: draft.selectedAsExecutor,
                  title: 'Меня выбрали исполнителем',
                  onChanged: (value) {
                    setState(() {
                      _draft = NotificationSettings(
                        newRequestsInCommunities:
                            draft.newRequestsInCommunities,
                        responsesToMyRequests: draft.responsesToMyRequests,
                        selectedAsExecutor: value,
                        newReviews: draft.newReviews,
                        subscribedCategoryIds: draft.subscribedCategoryIds,
                      );
                    });
                  },
                ),
                _NotificationToggleTile(
                  value: draft.newReviews,
                  title: 'Новые отзывы',
                  onChanged: (value) {
                    setState(() {
                      _draft = NotificationSettings(
                        newRequestsInCommunities:
                            draft.newRequestsInCommunities,
                        responsesToMyRequests: draft.responsesToMyRequests,
                        selectedAsExecutor: draft.selectedAsExecutor,
                        newReviews: value,
                        subscribedCategoryIds: draft.subscribedCategoryIds,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          if (draft.newRequestsInCommunities) ...[
            const SizedBox(height: 16),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ServiceCategorySelectionSummary(
                    title: 'Подписки на категории',
                    subtitle:
                        'Категории позволяют получать только те запросы, которые действительно подходят вам по интересам и навыкам.',
                    selectedTitles: draft.subscribedCategoryIds,
                    actionLabel: 'Выбрать категории',
                    onTap: () async {
                      final selected = await showMultiServiceCategoryPicker(
                        context,
                        selectedTitles: draft.subscribedCategoryIds,
                      );
                      if (selected == null) {
                        return;
                      }
                      setState(() {
                        _draft = NotificationSettings(
                          newRequestsInCommunities:
                              draft.newRequestsInCommunities,
                          responsesToMyRequests: draft.responsesToMyRequests,
                          selectedAsExecutor: draft.selectedAsExecutor,
                          newReviews: draft.newReviews,
                          subscribedCategoryIds: selected,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: state.loading
                ? null
                : () async {
                    final success = await ref
                        .read(profileControllerProvider.notifier)
                        .updateNotificationSettings(draft);
                    if (!context.mounted) {
                      return;
                    }
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Настройки уведомлений сохранены'),
                        ),
                      );
                      context.pop();
                    }
                  },
            child: state.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  final bool value;
  final String title;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleTile({
    required this.value,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
