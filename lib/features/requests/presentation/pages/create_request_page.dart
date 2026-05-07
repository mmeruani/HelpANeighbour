import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/service_category_controls.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/request_enums.dart';
import '../controllers/request_controller.dart';

class CreateRequestPage extends ConsumerStatefulWidget {
  final String communityId;

  const CreateRequestPage({super.key, required this.communityId});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardAmountController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactDetailsController = TextEditingController();
  DateTime? _desiredExecutionAt;
  RequestUrgency _urgency = RequestUrgency.flexible;
  RewardType _rewardType = RewardType.none;
  String? _selectedCategory;

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

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AppPageHeader(
                title: 'Новый запрос',
                subtitle:
                    'Опишите, какая помощь вам нужна, чтобы соседям было легко откликнуться и понять условия с первого взгляда.',
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название запроса',
                      ),
                      validator: Validators.requestTitle,
                    ),
                    const SizedBox(height: 12),
                    ServiceCategoryField(
                      label: 'Категория услуги',
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
                      decoration: const InputDecoration(labelText: 'Описание'),
                      validator: Validators.requestDescription,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RequestUrgency>(
                      initialValue: _urgency,
                      decoration: const InputDecoration(labelText: 'Срочность'),
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
                          initialDate: _desiredExecutionAt ?? DateTime.now(),
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
                            ? 'Указать желаемое время выполнения'
                            : 'До ${_desiredExecutionAt!.day.toString().padLeft(2, '0')}.${_desiredExecutionAt!.month.toString().padLeft(2, '0')}.${_desiredExecutionAt!.year} ${_desiredExecutionAt!.hour.toString().padLeft(2, '0')}:${_desiredExecutionAt!.minute.toString().padLeft(2, '0')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RewardType>(
                      initialValue: _rewardType,
                      decoration: const InputDecoration(
                        labelText: 'Условия оплаты',
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
                          labelText: 'Сумма вознаграждения',
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
                        labelText: 'Контактные данные для связи',
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
                              final success = await ref
                                  .read(requestControllerProvider.notifier)
                                  .createRequest(
                                    communityId: widget.communityId,
                                    title: _titleController.text,
                                    category: _selectedCategory ?? '',
                                    description: _descriptionController.text,
                                    urgency: _urgency,
                                    desiredExecutionAt: _desiredExecutionAt,
                                    rewardType: _rewardType,
                                    rewardAmount:
                                        _rewardType == RewardType.fixed
                                        ? int.tryParse(
                                            _rewardAmountController.text,
                                          )
                                        : null,
                                    address: _addressController.text,
                                    contactDetails:
                                        _contactDetailsController.text,
                                  );
                              if (!context.mounted) {
                                return;
                              }
                              if (success) {
                                context.pop();
                              }
                            },
                      child: state.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Создать'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
