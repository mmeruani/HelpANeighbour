import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_sections.dart';
import '../controllers/review_controller.dart';

class UserReviewsPage extends ConsumerStatefulWidget {
  final String userId;

  const UserReviewsPage({super.key, required this.userId});

  @override
  ConsumerState<UserReviewsPage> createState() => _UserReviewsPageState();
}

class _UserReviewsPageState extends ConsumerState<UserReviewsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(reviewControllerProvider.notifier)
          .loadUserReviews(widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider);
    final reviewsCount = state.reviews.length;
    final averageRating = reviewsCount == 0
        ? 0.0
        : state.reviews.map((review) => review.rating).reduce((a, b) => a + b) /
              reviewsCount;

    return Scaffold(
      appBar: AppBar(),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AppPageHeader(
                  title: 'Отзывы',
                  subtitle:
                      'Здесь собраны впечатления людей о взаимодействии с пользователем и качестве помощи.',
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ReviewSummaryValue(
                          label: 'Общий рейтинг',
                          value: reviewsCount == 0
                              ? 'Нет рейтинга'
                              : averageRating.toStringAsFixed(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReviewSummaryValue(
                          label: 'Отзывов',
                          value: reviewsCount.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (state.error != null) ...[
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.reviews.isEmpty)
                  const AppSectionCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('Отзывов пока нет')),
                    ),
                  )
                else
                  ...state.reviews.map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage:
                                      review.customerAvatarUrl != null &&
                                          review.customerAvatarUrl!.isNotEmpty
                                      ? NetworkImage(review.customerAvatarUrl!)
                                      : null,
                                  child:
                                      review.customerAvatarUrl == null ||
                                          review.customerAvatarUrl!.isEmpty
                                      ? Text(
                                          review.customerName.isEmpty
                                              ? '?'
                                              : review.customerName
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    review.customerName.isEmpty
                                        ? 'Заказчик'
                                        : review.customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Оценка: ${review.rating}/5',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              review.text.isEmpty
                                  ? 'Текст отзыва не указан'
                                  : review.text,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Дата: ${review.createdAt.day.toString().padLeft(2, '0')}.${review.createdAt.month.toString().padLeft(2, '0')}.${review.createdAt.year}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReviewSummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewSummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
