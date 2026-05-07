import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/notification_bell_button.dart';
import '../../../auth/presentation/auth_session_reset.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../community/presentation/controllers/community_controller.dart';
import '../controllers/profile_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Timer? _slowLoadTimer;
  bool _showSlowLoadError = false;

  @override
  void initState() {
    super.initState();
    _startSlowLoadTimer();
  }

  @override
  void dispose() {
    _cancelSlowLoadTimer();
    super.dispose();
  }

  void _cancelSlowLoadTimer() {
    _slowLoadTimer?.cancel();
    _slowLoadTimer = null;
  }

  void _startSlowLoadTimer() {
    _cancelSlowLoadTimer();
    _showSlowLoadError = false;
    _slowLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() => _showSlowLoadError = true);
      }
    });
  }

  void _retryLoad() {
    setState(_startSlowLoadTimer);
    ref.read(profileControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final communityState = ref.watch(communityControllerProvider);
    final profile = state.profile;
    if (profile != null) {
      _cancelSlowLoadTimer();
    } else if (_slowLoadTimer == null && !_showSlowLoadError) {
      _startSlowLoadTimer();
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 188,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/communities'),
              icon: const Icon(Icons.home_work_outlined, size: 18),
              label: const Text('К моим сообществам'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text('Профиль'),
        actions: const [NotificationBellButton()],
      ),
      body: profile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: !_showSlowLoadError
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.error ??
                                'Профиль пока не загрузился. Проверьте подключение и попробуйте ещё раз.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _retryLoad,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppPageHeader(
                  title: profile.name.isEmpty ? 'Ваш профиль' : profile.name,
                  subtitle:
                      'Личный кабинет, отзывы, история действий и ваши сообщества — всё в одном месте.',
                  trailing: CircleAvatar(
                    radius: 32,
                    backgroundImage:
                        profile.avatarUrl != null &&
                            profile.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child:
                        profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                        ? Text(
                            profile.name.isEmpty
                                ? '?'
                                : profile.name.substring(0, 1).toUpperCase(),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Контакты',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'О себе',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.bio.isEmpty
                            ? 'Краткое описание пока не заполнено'
                            : profile.bio,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = math.max(
                      120.0,
                      (constraints.maxWidth - 12) / 2,
                    );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _MetricChip(
                            label: 'Рейтинг',
                            value: profile.reviewsCount == 0
                                ? 'Нет рейтинга · отзывов: 0'
                                : '${profile.rating.toStringAsFixed(1)} · отзывов: ${profile.reviewsCount}',
                            onTap: () => context.push(
                              '/profile/reviews/${profile.userId}',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _MetricChip(
                            label: 'Выполнено услуг',
                            value: profile.completedServicesCount.toString(),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _MetricChip(
                            label: 'Отзывов',
                            value: profile.reviewsCount.toString(),
                            onTap: () => context.push(
                              '/profile/reviews/${profile.userId}',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _MetricChip(
                            label: 'Сообществ',
                            value: profile.communityIds.length.toString(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push('/profile/edit'),
                        child: const Text('Редактировать профиль'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => context.push('/profile/notifications'),
                        child: const Text('Настройки уведомлений'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/reviews/${profile.userId}'),
                        child: const Text('Мои отзывы'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/completed-services'),
                        child: const Text('Завершённые услуги'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/customer-history'),
                        child: const Text('История заказчика'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/executor-history'),
                        child: const Text('История исполнителя'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Сообщества',
                        subtitle: 'Пространства, в которых вы сейчас состоите.',
                      ),
                      const SizedBox(height: 12),
                      if (profile.communityIds.isEmpty)
                        const Text('Пользователь пока не состоит в сообществах')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.communityIds.map((communityId) {
                            final matches = communityState.communities.where(
                              (community) => community.id == communityId,
                            );
                            final match = matches.isEmpty
                                ? null
                                : matches.first;
                            return Chip(
                              label: Text(
                                match == null ? communityId : match.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Выйти из аккаунта?'),
                        content: const Text(
                          'Вы уверены, что хотите выйти из аккаунта?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Нет'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Выйти'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) {
                      return;
                    }
                    await ref.read(authControllerProvider.notifier).logout();
                    resetUserScopedProviders(ref);
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  child: const Text('Выйти'),
                ),
              ],
            ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _MetricChip({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: content,
        ),
      ),
    );
  }
}
