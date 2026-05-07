import 'package:flutter/material.dart';

import '../../features/requests/domain/entities/request_enums.dart';

class RequestStatusBadge extends StatelessWidget {
  final RequestStatus status;

  const RequestStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = requestStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        requestStatusLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color requestStatusColor(RequestStatus status) {
  switch (status) {
    case RequestStatus.active:
      return Colors.green.shade700;
    case RequestStatus.inProgress:
      return Colors.amber.shade800;
    case RequestStatus.awaitingCustomerConfirmation:
      return Colors.orange.shade800;
    case RequestStatus.completed:
      return Colors.blue.shade700;
    case RequestStatus.cancelled:
      return Colors.red.shade700;
  }
}

String requestStatusLabel(RequestStatus status) {
  switch (status) {
    case RequestStatus.active:
      return 'Активен';
    case RequestStatus.inProgress:
      return 'В процессе';
    case RequestStatus.awaitingCustomerConfirmation:
      return 'Ожидает подтверждения заказчиком';
    case RequestStatus.completed:
      return 'Выполнен';
    case RequestStatus.cancelled:
      return 'Отменён';
  }
}
