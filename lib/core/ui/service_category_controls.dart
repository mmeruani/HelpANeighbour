import 'package:flutter/material.dart';

import '../config/service_categories.dart';

Future<String?> showSingleServiceCategoryPicker(
  BuildContext context, {
  String? selectedTitle,
  String title = 'Категория услуги',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Выберите категорию, чтобы соседям было легче найти и отфильтровать запрос.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: ServiceCategories.all.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = ServiceCategories.all[index];
                      final isSelected = category.title == selectedTitle;
                      return _ServiceCategoryTile(
                        title: category.title,
                        subtitle: category.examples,
                        isSelected: isSelected,
                        onTap: () => Navigator.of(context).pop(category.title),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<List<String>?> showMultiServiceCategoryPicker(
  BuildContext context, {
  required List<String> selectedTitles,
  String title = 'Подписки на категории',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ServiceCategoryMultiSelectSheet(
        title: title,
        initialSelection: selectedTitles,
      );
    },
  );
}

class ServiceCategoryField extends FormField<String> {
  ServiceCategoryField({
    super.key,
    required String label,
    required String hintText,
    super.initialValue,
    super.validator,
    ValueChanged<String?>? onChanged,
  }) : super(
          builder: (field) {
            final theme = Theme.of(field.context);
            final selectedCategory = ServiceCategories.byTitle(field.value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final selected = await showSingleServiceCategoryPicker(
                      field.context,
                      selectedTitle: field.value,
                    );
                    if (selected == null) {
                      return;
                    }
                    field.didChange(selected);
                    onChanged?.call(selected);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      errorText: field.errorText,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.value?.isNotEmpty == true
                                ? field.value!
                                : hintText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: field.value?.isNotEmpty == true
                                ? theme.textTheme.bodyLarge
                                : theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                if (selectedCategory != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    selectedCategory.examples,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            );
          },
        );
}

class ServiceCategorySelectionSummary extends StatelessWidget {
  final List<String> selectedTitles;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String actionLabel;

  const ServiceCategorySelectionSummary({
    super.key,
    required this.selectedTitles,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.tune_rounded),
          label: Text(actionLabel),
        ),
        if (selectedTitles.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedTitles.map((title) {
              final category = ServiceCategories.byTitle(title);
              return Tooltip(
                message: category?.examples ?? title,
                child: Chip(
                  label: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _ServiceCategoryMultiSelectSheet extends StatefulWidget {
  final String title;
  final List<String> initialSelection;

  const _ServiceCategoryMultiSelectSheet({
    required this.title,
    required this.initialSelection,
  });

  @override
  State<_ServiceCategoryMultiSelectSheet> createState() =>
      _ServiceCategoryMultiSelectSheetState();
}

class _ServiceCategoryMultiSelectSheetState
    extends State<_ServiceCategoryMultiSelectSheet> {
  late final Set<String> _selectedTitles = widget.initialSelection.toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Отмеченные категории будут использоваться для подписок и быстрой фильтрации.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ServiceCategories.all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = ServiceCategories.all[index];
                    final isSelected = _selectedTitles.contains(category.title);
                    return _ServiceCategoryTile(
                      title: category.title,
                      subtitle: category.examples,
                      isSelected: isSelected,
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggle(category.title),
                      ),
                      onTap: () => _toggle(category.title),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _selectedTitles.toList(),
                      ),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String title) {
    setState(() {
      if (_selectedTitles.contains(title)) {
        _selectedTitles.remove(title);
      } else {
        _selectedTitles.add(title);
      }
    });
  }
}

class _ServiceCategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ServiceCategoryTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.95)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.55)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
