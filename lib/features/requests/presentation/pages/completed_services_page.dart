import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/request_status_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/service_request.dart';
import '../controllers/request_controller.dart';

class CompletedServicesPage extends ConsumerStatefulWidget {
  const CompletedServicesPage({super.key});

  @override
  ConsumerState<CompletedServicesPage> createState() =>
      _CompletedServicesPageState();
}

class _CompletedServicesPageState extends ConsumerState<CompletedServicesPage> {
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
    final currentUserId = ref.watch(currentUserIdProvider);
    final completedAsCustomer =
        state.myRequests
            .where(
              (request) =>
                  request.status == RequestStatus.completed ||
                  request.status == RequestStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final completedAsExecutor =
        state.executorHistory
            .where(
              (request) =>
                  (request.status == RequestStatus.completed ||
                      request.status == RequestStatus.cancelled) &&
                  request.executorId == currentUserId,
            )
            .toList()
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
              title: 'Завершённые услуги',
              subtitle:
                  'Здесь собраны запросы, которые уже не находятся в работе: выполненные и отменённые.',
            ),
            const SizedBox(height: 18),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            const AppSectionTitle(title: 'Как заказчик'),
            const SizedBox(height: 8),
            if (completedAsCustomer.isEmpty)
              const AppSectionCard(
                child: Text(
                  'Завершённых или отменённых запросов как заказчик пока нет',
                ),
              )
            else
              ...completedAsCustomer.map(
                (request) => _CompletedRequestCard(
                  request: request,
                  currentUserId: currentUserId,
                ),
              ),
            const SizedBox(height: 20),
            const AppSectionTitle(title: 'Как исполнитель'),
            const SizedBox(height: 8),
            if (completedAsExecutor.isEmpty)
              const AppSectionCard(
                child: Text(
                  'Завершённых или отменённых запросов как исполнитель пока нет',
                ),
              )
            else
              ...completedAsExecutor.map(
                (request) => _CompletedRequestCard(
                  request: request,
                  currentUserId: currentUserId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompletedRequestCard extends StatelessWidget {
  final ServiceRequest request;
  final String? currentUserId;

  const _CompletedRequestCard({
    required this.request,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final canLeaveReview =
        currentUserId == request.customerId && request.executorId != null;

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
              RequestStatusBadge(status: request.status),
              const SizedBox(height: 4),
              Text(
                'Дата завершения: ${request.updatedAt.day.toString().padLeft(2, '0')}.${request.updatedAt.month.toString().padLeft(2, '0')}.${request.updatedAt.year} ${request.updatedAt.hour.toString().padLeft(2, '0')}:${request.updatedAt.minute.toString().padLeft(2, '0')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Сообщество: ${request.communityName.isEmpty ? request.communityId : request.communityName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Исполнитель: ${request.executorName?.isNotEmpty == true ? request.executorName! : 'Не указан'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (canLeaveReview) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/requests/${request.id}/review/${request.executorId}',
                    ),
                    child: const Text('Оставить отзыв'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
