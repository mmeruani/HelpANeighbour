import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/request_status_badge.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/service_request.dart';
import '../controllers/request_controller.dart';

class ExecutorHistoryPage extends ConsumerStatefulWidget {
  const ExecutorHistoryPage({super.key});

  @override
  ConsumerState<ExecutorHistoryPage> createState() =>
      _ExecutorHistoryPageState();
}

class _ExecutorHistoryPageState extends ConsumerState<ExecutorHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(requestControllerProvider.notifier).loadUserHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestControllerProvider);
    final items = state.executorHistory.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(requestControllerProvider.notifier).loadUserHistory(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppPageHeader(
              title: 'История исполнителя',
              subtitle:
                  'Вся ваша исполнительская активность: какие задачи вы брали, на каком они этапе и чем завершились.',
            ),
            const SizedBox(height: 18),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (items.isEmpty)
              const AppSectionCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('История исполнителя пока пуста'),
                        SizedBox(height: 8),
                        Text('Попробуйте обновить страницу'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...items.map((request) => _ExecutorHistoryCard(request: request)),
          ],
        ),
      ),
    );
  }
}

class _ExecutorHistoryCard extends StatelessWidget {
  final ServiceRequest request;

  const _ExecutorHistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/requests/${request.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Заказчик: ${request.customerName.isEmpty ? 'Пользователь' : request.customerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Сообщество: ${request.communityName.isEmpty ? request.communityId : request.communityName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RequestStatusBadge(status: request.status),
              const SizedBox(height: 4),
              Text(
                'Последнее изменение: ${request.updatedAt.day.toString().padLeft(2, '0')}.${request.updatedAt.month.toString().padLeft(2, '0')}.${request.updatedAt.year} ${request.updatedAt.hour.toString().padLeft(2, '0')}:${request.updatedAt.minute.toString().padLeft(2, '0')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Оплата: ${request.rewardType == RewardType.none
                    ? 'Без оплаты'
                    : request.rewardType == RewardType.negotiable
                    ? 'По договорённости'
                    : '${request.rewardAmount ?? 0} ₽'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _ExecutorTimelineLine(
                text:
                    'Отклик отправлен, запрос создан ${_formatDateTime(request.createdAt)}',
              ),
              if (request.executorId != null)
                const _ExecutorTimelineLine(
                  text: 'Исполнитель выбран заказчиком',
                ),
              _ExecutorTimelineLine(
                text:
                    'Последнее изменение: ${_formatDateTime(request.updatedAt)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutorTimelineLine extends StatelessWidget {
  final String text;

  const _ExecutorTimelineLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
