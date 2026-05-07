import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/request_status_badge.dart';
import '../../../../core/ui/service_category_controls.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/service_request.dart';
import '../controllers/request_controller.dart';

class CommunityRequestsPage extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityRequestsPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityRequestsPage> createState() =>
      _CommunityRequestsPageState();
}

class _CommunityRequestsPageState extends ConsumerState<CommunityRequestsPage> {
  int _tabIndex = 0;
  final _searchController = TextEditingController();
  String? _selectedCategory;
  RequestUrgency? _selectedUrgency;
  RequestStatus? _selectedStatus;
  bool _withRewardOnly = false;
  DateTime? _executionFrom;
  DateTime? _executionTo;
  final _minRewardController = TextEditingController();
  final _maxRewardController = TextEditingController();
  String? _filterError;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(requestControllerProvider.notifier)
          .loadCommunityRequests(widget.communityId),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minRewardController.dispose();
    _maxRewardController.dispose();
    super.dispose();
  }

  Future<void> _pickExecutionRange(BuildContext context) async {
    final fromDate = await showDatePicker(
      context: context,
      initialDate: _executionFrom ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (fromDate == null || !context.mounted) {
      return;
    }
    final toDate = await showDatePicker(
      context: context,
      initialDate: _executionTo ?? fromDate,
      firstDate: fromDate,
      lastDate: DateTime(2100),
    );
    if (toDate == null) {
      return;
    }
    setState(() {
      _executionFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
      _executionTo = DateTime(toDate.year, toDate.month, toDate.day, 23, 59);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestControllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final sourceRequests = _tabIndex == 0
        ? state.communityRequests
        : _tabIndex == 1
        ? state.communityRequests
              .where((request) => request.customerId == currentUserId)
              .toList()
        : state.communityRequests
              .where((request) => request.executorId == currentUserId)
              .toList();
    final filtersAreValid =
        Validators.filterReward(_minRewardController.text) == null &&
        Validators.filterReward(_maxRewardController.text) == null;
    final requests = sourceRequests.where((request) {
      if (!filtersAreValid) {
        return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      final searchMatches =
          query.isEmpty ||
          request.title.toLowerCase().contains(query) ||
          request.description.toLowerCase().contains(query) ||
          request.category.toLowerCase().contains(query) ||
          request.customerName.toLowerCase().contains(query);
      final categoryMatches =
          _selectedCategory == null || request.category == _selectedCategory;
      final urgencyMatches =
          _selectedUrgency == null || request.urgency == _selectedUrgency;
      final statusMatches =
          _selectedStatus == null || request.status == _selectedStatus;
      final rewardMatches =
          !_withRewardOnly || request.rewardType != RewardType.none;
      final executionFromMatches =
          _executionFrom == null ||
          (request.desiredExecutionAt != null &&
              !request.desiredExecutionAt!.isBefore(_executionFrom!));
      final executionToMatches =
          _executionTo == null ||
          (request.desiredExecutionAt != null &&
              !request.desiredExecutionAt!.isAfter(_executionTo!));
      final minReward = int.tryParse(_minRewardController.text);
      final maxReward = int.tryParse(_maxRewardController.text);
      if (minReward != null && maxReward != null && minReward > maxReward) {
        return false;
      }
      final rewardAmount = request.rewardAmount ?? 0;
      final minRewardMatches = minReward == null || rewardAmount >= minReward;
      final maxRewardMatches = maxReward == null || rewardAmount <= maxReward;
      return searchMatches &&
          categoryMatches &&
          urgencyMatches &&
          statusMatches &&
          rewardMatches &&
          executionFromMatches &&
          executionToMatches &&
          minRewardMatches &&
          maxRewardMatches;
    }).toList();
    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(requestControllerProvider.notifier)
            .loadCommunityRequests(widget.communityId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppPageHeader(
              title: 'Запросы сообщества',
              subtitle:
                  'Следите за актуальными задачами, своими обращениями и принятыми услугами.',
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/communities/${widget.communityId}/requests/create',
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Создать запрос'),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Лента')),
                        ButtonSegment(value: 1, label: Text('Мои запросы')),
                        ButtonSegment(value: 2, label: Text('Принятые')),
                      ],
                      selected: {_tabIndex},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _tabIndex = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            AppSectionCard(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Поиск по запросам',
                      hintText:
                          'Название, описание, категория или имя заказчика',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ServiceCategorySelectionSummary(
                    title: 'Категории и быстрый поиск',
                    subtitle:
                        'Категории подобраны под типичные соседские задачи. Под каждой из них скрыты примеры, чтобы фильтрация была понятной и предсказуемой.',
                    selectedTitles: _selectedCategory == null
                        ? const []
                        : [_selectedCategory!],
                    actionLabel: _selectedCategory == null
                        ? 'Выбрать категорию'
                        : 'Изменить категорию',
                    onTap: () async {
                      final selected = await showSingleServiceCategoryPicker(
                        context,
                        selectedTitle: _selectedCategory,
                        title: 'Фильтр по категории',
                      );
                      if (selected == null) {
                        return;
                      }
                      setState(() {
                        _selectedCategory = selected;
                      });
                    },
                  ),
                  if (_selectedCategory != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                          });
                        },
                        child: const Text('Сбросить категорию'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RequestUrgency?>(
                    initialValue: _selectedUrgency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Срочность'),
                    items: const [
                      DropdownMenuItem<RequestUrgency?>(
                        value: null,
                        child: Text('Любая'),
                      ),
                      DropdownMenuItem<RequestUrgency?>(
                        value: RequestUrgency.urgent,
                        child: Text('Срочный'),
                      ),
                      DropdownMenuItem<RequestUrgency?>(
                        value: RequestUrgency.flexible,
                        child: Text('Несрочный'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUrgency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RequestStatus?>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Статус'),
                    items: const [
                      DropdownMenuItem<RequestStatus?>(
                        value: null,
                        child: Text('Любой статус'),
                      ),
                      DropdownMenuItem<RequestStatus?>(
                        value: RequestStatus.active,
                        child: Text('Активен'),
                      ),
                      DropdownMenuItem<RequestStatus?>(
                        value: RequestStatus.inProgress,
                        child: Text('В процессе'),
                      ),
                      DropdownMenuItem<RequestStatus?>(
                        value: RequestStatus.awaitingCustomerConfirmation,
                        child: Text('Ожидает подтверждения'),
                      ),
                      DropdownMenuItem<RequestStatus?>(
                        value: RequestStatus.completed,
                        child: Text('Выполнен'),
                      ),
                      DropdownMenuItem<RequestStatus?>(
                        value: RequestStatus.cancelled,
                        child: Text('Отменён'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Только с вознаграждением'),
                    value: _withRewardOnly,
                    onChanged: (value) {
                      setState(() {
                        _withRewardOnly = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickExecutionRange(context),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _executionFrom == null && _executionTo == null
                          ? 'Срок выполнения: любой'
                          : 'Срок: ${_formatDateTime(_executionFrom)} - ${_formatDateTime(_executionTo)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_executionFrom != null || _executionTo != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _executionFrom = null;
                            _executionTo = null;
                          });
                        },
                        child: const Text('Сбросить срок'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minRewardController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Мин. сумма',
                          ),
                          onChanged: (_) => _updateFilterValidation(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxRewardController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Макс. сумма',
                          ),
                          onChanged: (_) => _updateFilterValidation(),
                        ),
                      ),
                    ],
                  ),
                  if (_filterError != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _filterError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.loading && state.communityRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
              const AppSectionCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(
                    child: Text(
                      'В этом сообществе пока нет запросов',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ...requests.map(
                (request) => _RequestCard(
                  request: request,
                  onTap: () => context.push('/requests/${request.id}'),
                  onDelete:
                      _tabIndex == 1 &&
                          (request.status == RequestStatus.completed ||
                              request.status == RequestStatus.cancelled)
                      ? () async {
                          await ref
                              .read(requestControllerProvider.notifier)
                              .deleteRequestFromHistory(
                                requestId: request.id,
                                communityId: widget.communityId,
                              );
                        }
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _updateFilterValidation() {
    final minError = Validators.filterReward(_minRewardController.text);
    final maxError = Validators.filterReward(_maxRewardController.text);
    final minReward = int.tryParse(_minRewardController.text.trim());
    final maxReward = int.tryParse(_maxRewardController.text.trim());

    setState(() {
      if (minError != null || maxError != null) {
        _filterError = 'Некорректные параметры фильтрации';
      } else if (minReward != null &&
          maxReward != null &&
          minReward > maxReward) {
        _filterError =
            'Некорректные параметры фильтрации: минимальная сумма больше максимальной';
      } else {
        _filterError = null;
      }
    });
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _RequestCard({
    required this.request,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSectionCard(
        padding: const EdgeInsets.all(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      request.rewardType == RewardType.none
                          ? 'Без оплаты'
                          : request.rewardType == RewardType.negotiable
                          ? 'Договорная'
                          : '${request.rewardAmount ?? 0} ₽',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RequestMetaChip(label: request.category),
                  _RequestMetaChip(
                    label: request.urgency == RequestUrgency.urgent
                        ? 'Срочный'
                        : 'Несрочный',
                  ),
                  RequestStatusBadge(status: request.status),
                  _RequestMetaChip(
                    label: 'Откликов: ${request.responsesCount}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Заказчик: ${request.customerName.isEmpty ? 'Пользователь' : request.customerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Опубликован: ${request.createdAt.day.toString().padLeft(2, '0')}.${request.createdAt.month.toString().padLeft(2, '0')}.${request.createdAt.year} ${request.createdAt.hour.toString().padLeft(2, '0')}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (request.executorId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Исполнитель: ${request.executorName?.isNotEmpty == true ? request.executorName! : 'Исполнитель'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.desiredExecutionAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Выполнить до: ${request.desiredExecutionAt!.day.toString().padLeft(2, '0')}.${request.desiredExecutionAt!.month.toString().padLeft(2, '0')}.${request.desiredExecutionAt!.year} ${request.desiredExecutionAt!.hour.toString().padLeft(2, '0')}:${request.desiredExecutionAt!.minute.toString().padLeft(2, '0')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.address?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Адрес: ${request.address!.trim()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
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

class _RequestMetaChip extends StatelessWidget {
  final String label;

  const _RequestMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'не задан';
  }
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
