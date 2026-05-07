import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/service_categories.dart';
import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/service_category_controls.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/service_request.dart';
import '../controllers/request_controller.dart';

class EditRequestPage extends ConsumerStatefulWidget {
  final String requestId;

  const EditRequestPage({super.key, required this.requestId});

  @override
  ConsumerState<EditRequestPage> createState() => _EditRequestPageState();
}

class _EditRequestPageState extends ConsumerState<EditRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardAmountController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactDetailsController = TextEditingController();
  RequestUrgency _urgency = RequestUrgency.flexible;
  RewardType _rewardType = RewardType.none;
  DateTime? _desiredExecutionAt;
  bool _initialized = false;
  String? _selectedCategory;

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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardAmountController.dispose();
    _addressController.dispose();
    _contactDetailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestControllerProvider);
    final request = state.selectedRequest;

    if (request != null && !_initialized) {
      _applyRequest(request);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(),
      body: request == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AppPageHeader(
                    title: 'Редактирование запроса',
                    subtitle:
                        'Обновите описание, сроки и условия так, чтобы исполнителю было легко принять решение.',
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Название',
                          ),
                          validator: Validators.requestTitle,
                        ),
                        const SizedBox(height: 12),
                        ServiceCategoryField(
                          label: 'Категория',
                          hintText: 'Выберите категорию из списка',
                          initialValue: _selectedCategory,
                          validator: Validators.customCategory,
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                          ),
                          validator: Validators.requestDescription,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RequestUrgency>(
                          initialValue: _urgency,
                          decoration: const InputDecoration(
                            labelText: 'Срочность',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: RequestUrgency.flexible,
                              child: Text('Несрочный'),
                            ),
                            DropdownMenuItem(
                              value: RequestUrgency.urgent,
                              child: Text('Срочный'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _urgency = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate:
                                  _desiredExecutionAt ?? DateTime.now(),
                            );
                            if (date == null || !context.mounted) {
                              return;
                            }
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                _desiredExecutionAt ?? DateTime.now(),
                              ),
                            );
                            if (time == null) {
                              return;
                            }
                            setState(() {
                              _desiredExecutionAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _desiredExecutionAt == null
                                ? 'Указать время выполнения'
                                : 'До ${_desiredExecutionAt!.day.toString().padLeft(2, '0')}.${_desiredExecutionAt!.month.toString().padLeft(2, '0')}.${_desiredExecutionAt!.year} ${_desiredExecutionAt!.hour.toString().padLeft(2, '0')}:${_desiredExecutionAt!.minute.toString().padLeft(2, '0')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RewardType>(
                          initialValue: _rewardType,
                          decoration: const InputDecoration(
                            labelText: 'Оплата',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: RewardType.none,
                              child: Text('Без оплаты'),
                            ),
                            DropdownMenuItem(
                              value: RewardType.negotiable,
                              child: Text('По договорённости'),
                            ),
                            DropdownMenuItem(
                              value: RewardType.fixed,
                              child: Text('Фиксированная сумма'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _rewardType = value;
                              });
                            }
                          },
                        ),
                        if (_rewardType == RewardType.fixed) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _rewardAmountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Сумма',
                            ),
                            validator: (value) {
                              if (_rewardType != RewardType.fixed) {
                                return null;
                              }
                              return Validators.rewardAmount(value);
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactDetailsController,
                          decoration: const InputDecoration(
                            labelText: 'Контакты',
                          ),
                          validator: Validators.contactDetails,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Адрес выполнения (необязательно)',
                          ),
                          validator: Validators.requestAddress,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: state.loading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final updated = ServiceRequest(
                                    id: request.id,
                                    communityId: request.communityId,
                                    communityName: request.communityName,
                                    customerId: request.customerId,
                                    customerName: request.customerName,
                                    customerAvatarUrl:
                                        request.customerAvatarUrl,
                                    customerRating: request.customerRating,
                                    customerReviewsCount:
                                        request.customerReviewsCount,
                                    executorId: request.executorId,
                                    executorName: request.executorName,
                                    executorAvatarUrl:
                                        request.executorAvatarUrl,
                                    executorRating: request.executorRating,
                                    executorReviewsCount:
                                        request.executorReviewsCount,
                                    title: _titleController.text.trim(),
                                    category: (_selectedCategory ?? '').trim(),
                                    description: _descriptionController.text
                                        .trim(),
                                    urgency: _urgency,
                                    desiredExecutionAt: _desiredExecutionAt,
                                    rewardType: _rewardType,
                                    rewardAmount:
                                        _rewardType == RewardType.fixed
                                        ? int.tryParse(
                                            _rewardAmountController.text,
                                          )
                                        : null,
                                    address: _addressController.text.trim(),
                                    contactDetails: _contactDetailsController
                                        .text
                                        .trim(),
                                    status: request.status,
                                    responsesCount: request.responsesCount,
                                    createdAt: request.createdAt,
                                    updatedAt: DateTime.now(),
                                  );
                                  final success = await ref
                                      .read(requestControllerProvider.notifier)
                                      .updateRequest(updated);
                                  if (context.mounted && success) {
                                    context.pop();
                                  }
                                },
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Категории запросов',
                          subtitle:
                              'Используйте единые категории, чтобы исполнителям было проще находить и фильтровать похожие задачи.',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ServiceCategories.all
                              .map(
                                (category) => Tooltip(
                                  message: category.examples,
                                  child: Chip(
                                    label: Text(
                                      category.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _applyRequest(ServiceRequest request) {
    _titleController.text = request.title;
    _descriptionController.text = request.description;
    _rewardAmountController.text = request.rewardAmount?.toString() ?? '';
    _addressController.text = request.address ?? '';
    _contactDetailsController.text = request.contactDetails;
    _urgency = request.urgency;
    _rewardType = request.rewardType;
    _desiredExecutionAt = request.desiredExecutionAt;
    _selectedCategory = ServiceCategories.contains(request.category)
        ? request.category
        : 'Другое';
  }
}
