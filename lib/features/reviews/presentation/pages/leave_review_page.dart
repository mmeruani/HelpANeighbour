import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/review_controller.dart';

class LeaveReviewPage extends ConsumerStatefulWidget {
  final String requestId;
  final String executorId;

  const LeaveReviewPage({
    super.key,
    required this.requestId,
    required this.executorId,
  });

  @override
  ConsumerState<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends ConsumerState<LeaveReviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  int? _rating;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Оставить отзыв')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _loadPublicUserCard(widget.executorId),
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? <String, dynamic>{};
                    final name = (data['name'] as String?) ?? '';
                    final avatarUrl = data['avatarUrl'] as String?;
                    final rating = ((data['rating'] as num?) ?? 0).toDouble();
                    final reviewsCount = ((data['reviewsCount'] as num?) ?? 0)
                        .toInt();
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  name.isEmpty
                                      ? '?'
                                      : name.substring(0, 1).toUpperCase(),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.isEmpty ? 'Исполнитель' : name),
                              Text(
                                reviewsCount == 0
                                    ? 'Нет рейтинга · 0 отзывов'
                                    : 'Рейтинг: ${rating.toStringAsFixed(1)} · отзывов: $reviewsCount',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Оцените работу исполнителя',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return ChoiceChip(
                      label: Text('$rating'),
                      selected: _rating == rating,
                      onSelected: (_) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _textController,
                  maxLines: 5,
                  maxLength: AppLimits.reviewTextMaxLength,
                  decoration: const InputDecoration(labelText: 'Текст отзыва'),
                  validator: Validators.reviewText,
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
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () async {
                          if (_rating == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Некорректная оценка'),
                              ),
                            );
                            return;
                          }
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          final success = await ref
                              .read(reviewControllerProvider.notifier)
                              .leaveReview(
                                requestId: widget.requestId,
                                executorId: widget.executorId,
                                rating: _rating!,
                                text: _textController.text,
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
                      : const Text('Сохранить отзыв'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> _loadPublicUserCard(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection(AppCollections.publicUsers)
        .doc(userId)
        .get();
    return snapshot.data() ?? <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}
