import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/request_status_badge.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/request_enums.dart';
import '../controllers/request_controller.dart';

class RequestDetailsPage extends ConsumerStatefulWidget {
  final String requestId;

  const RequestDetailsPage({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends ConsumerState<RequestDetailsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(requestControllerProvider.notifier)
          .loadRequestDetails(widget.requestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestControllerProvider);
    final request = state.selectedRequest;
    final currentUserId = ref.watch(currentUserIdProvider);
    final hasResponded =
        currentUserId != null &&
        state.responses.any((response) => response.executorId == currentUserId);
    final canSeeContacts =
        currentUserId == request?.customerId ||
        currentUserId == request?.executorId ||
        hasResponded;

    return Scaffold(
      appBar: AppBar(),
      body: request == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppPageHeader(
                  title: request.title,
                  subtitle:
                      'Подробная информация о задаче, условиях помощи и дальнейших шагах для заказчика и исполнителя.',
                  trailing: CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        request.customerAvatarUrl != null &&
                            request.customerAvatarUrl!.isNotEmpty
                        ? NetworkImage(request.customerAvatarUrl!)
                        : null,
                    child:
                        request.customerAvatarUrl == null ||
                            request.customerAvatarUrl!.isEmpty
                        ? Text(
                            request.customerName.isEmpty
                                ? '?'
                                : request.customerName
                                      .substring(0, 1)
                                      .toUpperCase(),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.customerName.isEmpty
                                  ? 'Пользователь'
                                  : request.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _RatingActionChip(
                            text: _ratingText(
                              request.customerRating,
                              request.customerReviewsCount,
                            ),
                            onTap: () => context.push(
                              '/profile/reviews/${request.customerId}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DetailsChip(label: request.category),
                          _DetailsChip(
                            label: request.urgency == RequestUrgency.urgent
                                ? 'Срочный'
                                : 'Несрочный',
                          ),
                          RequestStatusBadge(status: request.status),
                          _DetailsChip(
                            label: request.rewardType == RewardType.none
                                ? 'Без оплаты'
                                : request.rewardType == RewardType.negotiable
                                ? 'По договорённости'
                                : '${request.rewardAmount ?? 0} ₽',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        request.description.isEmpty
                            ? 'Описание не указано'
                            : request.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        request.desiredExecutionAt == null
                            ? 'Желаемое время выполнения не указано'
                            : 'Желаемое время выполнения: ${request.desiredExecutionAt!.day.toString().padLeft(2, '0')}.${request.desiredExecutionAt!.month.toString().padLeft(2, '0')}.${request.desiredExecutionAt!.year} ${request.desiredExecutionAt!.hour.toString().padLeft(2, '0')}:${request.desiredExecutionAt!.minute.toString().padLeft(2, '0')}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (request.address?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Адрес выполнения: ${request.address!.trim()}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Дата публикации: ${request.createdAt.day.toString().padLeft(2, '0')}.${request.createdAt.month.toString().padLeft(2, '0')}.${request.createdAt.year} ${request.createdAt.hour.toString().padLeft(2, '0')}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Количество откликов: ${request.responsesCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canSeeContacts
                            ? 'Контакты: ${request.contactDetails}'
                            : 'Контакты станут доступны после отклика на запрос',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (state.error != null) ...[
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AppSectionCard(
                  child: Column(
                    children: [
                      if (currentUserId != null &&
                          currentUserId != request.customerId &&
                          request.status == RequestStatus.active)
                        ElevatedButton(
                          onPressed: hasResponded
                              ? null
                              : () => _showRespondDialog(context),
                          child: Text(
                            hasResponded
                                ? 'Отклик уже отправлен'
                                : 'Откликнуться',
                          ),
                        ),
                      if (currentUserId != null &&
                          currentUserId != request.customerId &&
                          request.status == RequestStatus.active &&
                          hasResponded) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(requestControllerProvider.notifier)
                                .cancelResponse(widget.requestId);
                          },
                          child: const Text('Отозвать отклик'),
                        ),
                      ],
                      if (currentUserId == request.executorId &&
                          request.status == RequestStatus.inProgress) ...[
                        ElevatedButton(
                          onPressed: () => _showCompleteDialog(context),
                          child: const Text('Отметить как выполненный'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _showRefuseDialog(context),
                          child: const Text('Отказаться от выполнения'),
                        ),
                      ],
                      if (currentUserId == request.customerId &&
                          request.status ==
                              RequestStatus.awaitingCustomerConfirmation)
                        ElevatedButton(
                          onPressed: () => _showConfirmCompletionDialog(
                            context,
                            request.executorId,
                          ),
                          child: const Text('Подтвердить выполнение'),
                        ),
                      if (currentUserId == request.customerId &&
                          request.status == RequestStatus.completed &&
                          request.executorId != null) ...[
                        OutlinedButton(
                          onPressed: () => context.push(
                            '/requests/${widget.requestId}/review/${request.executorId}',
                          ),
                          child: const Text('Оставить отзыв'),
                        ),
                      ],
                      if (currentUserId == request.customerId &&
                          request.status == RequestStatus.active) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => context.push(
                            '/requests/${widget.requestId}/edit',
                          ),
                          child: const Text('Редактировать запрос'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _showCancelDialog(context),
                          child: const Text('Отменить запрос'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (currentUserId == request.customerId) ...[
                  const SizedBox(height: 16),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Отклики исполнителей',
                          subtitle:
                              'Люди, которые готовы помочь с этой задачей.',
                        ),
                        const SizedBox(height: 12),
                        if (state.responses.isEmpty)
                          const Text('Откликов пока нет')
                        else
                          ...state.responses.map(
                            (response) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppSectionCard(
                                padding: const EdgeInsets.all(16),
                                radius: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage:
                                              response.executorAvatarUrl !=
                                                      null &&
                                                  response
                                                      .executorAvatarUrl!
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                  response.executorAvatarUrl!,
                                                )
                                              : null,
                                          child:
                                              response.executorAvatarUrl ==
                                                      null ||
                                                  response
                                                      .executorAvatarUrl!
                                                      .isEmpty
                                              ? Text(
                                                  response.executorName.isEmpty
                                                      ? '?'
                                                      : response.executorName
                                                            .substring(0, 1)
                                                            .toUpperCase(),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            response.executorName.isEmpty
                                                ? 'Исполнитель'
                                                : response.executorName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      response.comment.isEmpty
                                          ? 'Без комментария'
                                          : response.comment,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () => context.push(
                                        '/profile/reviews/${response.executorId}',
                                      ),
                                      child: Text(
                                        _ratingText(
                                          response.executorRating,
                                          response.executorReviewsCount,
                                        ),
                                      ),
                                    ),
                                    if (request.status ==
                                        RequestStatus.active) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final success = await ref
                                                .read(
                                                  requestControllerProvider
                                                      .notifier,
                                                )
                                                .selectExecutor(
                                                  requestId: widget.requestId,
                                                  executorId:
                                                      response.executorId,
                                                );
                                            if (!context.mounted) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Исполнитель выбран'
                                                      : ref
                                                                .read(
                                                                  requestControllerProvider,
                                                                )
                                                                .error ??
                                                            'Не удалось выбрать исполнителя',
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('Выбрать'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _showCompleteDialog(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Подтвердить выполнение?'),
            content: const Text(
              'После подтверждения запрос перейдёт в состояние ожидания подтверждения заказчиком.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Подтвердить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref
        .read(requestControllerProvider.notifier)
        .markAsCompletedByExecutor(widget.requestId);
  }

  Future<void> _showConfirmCompletionDialog(
    BuildContext context,
    String? executorId,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Завершить услугу?'),
            content: const Text(
              'Система изменит статус запроса на "Выполнен" и откроет возможность оставить отзыв.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Завершить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final success = await ref
        .read(requestControllerProvider.notifier)
        .confirmCompletionByCustomer(widget.requestId);
    if (!context.mounted || !success) {
      return;
    }
    if (executorId != null) {
      context.push('/requests/${widget.requestId}/review/$executorId');
    }
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отменить запрос?'),
            content: const Text(
              'После отмены запрос получит статус "Отменён".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Нет'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Отменить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref
        .read(requestControllerProvider.notifier)
        .cancelRequest(widget.requestId);
  }

  Future<void> _showRespondDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _RespondRequestDialog(requestId: widget.requestId, ref: ref),
    );
  }

  Future<void> _showRefuseDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _RefuseExecutionDialog(requestId: widget.requestId, ref: ref),
    );
  }
}

class _RespondRequestDialog extends ConsumerStatefulWidget {
  final String requestId;
  final WidgetRef ref;

  const _RespondRequestDialog({required this.requestId, required this.ref});

  @override
  ConsumerState<_RespondRequestDialog> createState() =>
      _RespondRequestDialogState();
}

class _RespondRequestDialogState extends ConsumerState<_RespondRequestDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.responseComment(_controller.text);
    if (error != null) {
      setState(() {
        _error = error;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final success = await widget.ref
        .read(requestControllerProvider.notifier)
        .respondToRequest(
          requestId: widget.requestId,
          comment: _controller.text,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Отклик отправлен')));
      return;
    }
    setState(() {
      _submitting = false;
      _error =
          widget.ref.read(requestControllerProvider).error ??
          'Не удалось отправить отклик';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отклик на запрос'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: 300,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Комментарий (необязательно)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отправить'),
        ),
      ],
    );
  }
}

class _RefuseExecutionDialog extends ConsumerStatefulWidget {
  final String requestId;
  final WidgetRef ref;

  const _RefuseExecutionDialog({required this.requestId, required this.ref});

  @override
  ConsumerState<_RefuseExecutionDialog> createState() =>
      _RefuseExecutionDialogState();
}

class _RefuseExecutionDialogState
    extends ConsumerState<_RefuseExecutionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.responseComment(_controller.text);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final success = await widget.ref
        .read(requestControllerProvider.notifier)
        .refuseExecution(requestId: widget.requestId, reason: _controller.text);
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отказ от выполнения'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Причина отказа (необязательно)',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Подтвердить')),
      ],
    );
  }
}

class _DetailsChip extends StatelessWidget {
  final String label;

  const _DetailsChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _RatingActionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _RatingActionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

String _ratingText(double rating, int reviewsCount) {
  if (reviewsCount == 0) {
    return 'Нет рейтинга · 0 отзывов';
  }
  return 'Рейтинг ${rating.toStringAsFixed(1)} · отзывов: $reviewsCount';
}
