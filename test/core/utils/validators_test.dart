import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('accepts a valid russian phone', () {
      expect(Validators.phone('+79991234567'), isNull);
    });

    test('rejects invalid phone', () {
      expect(Validators.phone('89991234567'), 'Некорректный номер телефона');
    });

    test('normalizes common russian phone formats', () {
      expect(Validators.normalizePhone('89991234567'), '+79991234567');
      expect(Validators.normalizePhone('79991234567'), '+79991234567');
      expect(Validators.normalizePhone('9991234567'), '+79991234567');
      expect(Validators.normalizePhone('+7 (999) 123-45-67'), '+79991234567');
    });
  });

  group('Validators.email', () {
    test('accepts valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('rejects invalid email', () {
      expect(
        Validators.email('userexample.com'),
        'Некорректный адрес электронной почты',
      );
    });
  });

  group('Validators.password', () {
    test('accepts strong password', () {
      expect(Validators.password('Strong1!'), isNull);
    });

    test('rejects weak password', () {
      expect(Validators.password('weak'), isNotNull);
    });
  });

  group('Request-related validators', () {
    test('rejects invalid request title', () {
      expect(Validators.requestTitle(''), 'Некорректное название запроса');
    });

    test('accepts valid custom category', () {
      expect(Validators.customCategory('Домашняя помощь'), isNull);
    });

    test('rejects unknown category', () {
      expect(
        Validators.customCategory('Помощь по дому'),
        'Категория услуги не выбрана или некорректна',
      );
    });

    test('rejects short contact details', () {
      expect(
        Validators.contactDetails('1234'),
        'Некорректные контактные данные. Укажите телефон, ссылку или другой способ связи.',
      );
    });

    test('validates reward filter values', () {
      expect(Validators.filterReward(''), isNull);
      expect(Validators.filterReward('0'), isNull);
      expect(
        Validators.filterReward('-1'),
        'Некорректные параметры фильтрации',
      );
      expect(
        Validators.filterReward('abc'),
        'Некорректные параметры фильтрации',
      );
    });

    test('validates invitation codes', () {
      expect(Validators.invitationCode('ABC12345'), isNull);
      expect(
        Validators.invitationCode('short'),
        'Некорректный код приглашения',
      );
    });

    test('validates bounded text fields', () {
      expect(Validators.requestAddress('дом 13'), isNull);
      expect(Validators.reviewText('отлично'), isNull);
      expect(Validators.responseComment('готова помочь'), isNull);
    });
  });
}
