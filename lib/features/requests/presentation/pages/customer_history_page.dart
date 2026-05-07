import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/request_status_badge.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/service_request.dart';
import '../controllers/request_controller.dart';

class CustomerHistoryPage extends ConsumerStatefulWidget {
  const CustomerHistoryPage({super.key});

  @override
  ConsumerState<CustomerHistoryPage> createState() =>
      _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends ConsumerState<CustomerHistoryPage> {
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
    final items = state.myRequests.toList()
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
              title: 'История заказчика',
              subtitle:
                  'Все ваши запросы: где они созданы, кто откликнулся, какой сейчас статус и чем всё завершилось.',
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
                        Text('История заказчика пока пуста'),
                        SizedBox(height: 8),
                        Text('Попробуйте обновить страницу'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...items.map((request) => _CustomerHistoryCard(request: request)),
          ],
        ),
      ),
    );
  }
}

class _CustomerHistoryCard extends StatelessWidget {
  final ServiceRequest request;

  const _CustomerHistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Сообщество: ${request.communityName.isEmpty ? request.communityId : request.communityName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RequestStatusBadge(status: request.status),
              const SizedBox(height: 4),
              Text('Откликов: ${request.responsesCount}'),
              const SizedBox(height: 12),
              _TimelineLine(
                text: 'Создан: ${formatRequestDateTime(request.createdAt)}',
              ),
              if (request.responsesCount > 0)
                const _TimelineLine(text: 'Получены отклики исполнителей'),
              if (request.executorId != null)
                _TimelineLine(
                  text:
                      'Выбран исполнитель: ${request.executorName?.isNotEmpty == true ? request.executorName! : 'Исполнитель'}',
                ),
              _TimelineLine(
                text:
                    'Последнее изменение: ${formatRequestDateTime(request.updatedAt)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineLine extends StatelessWidget {
  final String text;

  const _TimelineLine({required this.text});

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

String formatRequestDateTime(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String requestStatusLabel(RequestStatus status) {
  switch (status) {
    case RequestStatus.active:
      return 'Активен';
    case RequestStatus.inProgress:
      return 'В процессе';
    case RequestStatus.awaitingCustomerConfirmation:
      return 'Ожидает подтверждения';
    case RequestStatus.completed:
      return 'Выполнен';
    case RequestStatus.cancelled:
      return 'Отменён';
  }
}
