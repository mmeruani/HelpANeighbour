import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/core/ui/request_status_badge.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_enums.dart';

void main() {
  group('requestStatusLabel', () {
    test('returns Russian labels for every request status', () {
      expect(requestStatusLabel(RequestStatus.active), 'Активен');
      expect(requestStatusLabel(RequestStatus.inProgress), 'В процессе');
      expect(
        requestStatusLabel(RequestStatus.awaitingCustomerConfirmation),
        'Ожидает подтверждения заказчиком',
      );
      expect(requestStatusLabel(RequestStatus.completed), 'Выполнен');
      expect(requestStatusLabel(RequestStatus.cancelled), 'Отменён');
    });
  });

  group('requestStatusColor', () {
    test('assigns a visible color for every request status', () {
      for (final status in RequestStatus.values) {
        expect(requestStatusColor(status), isNotNull);
      }
    });
  });
}
