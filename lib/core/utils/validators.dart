import '../config/constants.dart';
import '../config/service_categories.dart';

class Validators {
  static final RegExp _safeTextPattern = RegExp(
    "^[A-Za-zА-Яа-яЁё0-9\\s.,!?\"'():;+\\-_/&%@#№]+\$",
  );
  static final RegExp _invitationCodePattern = RegExp(
    '^[A-Z0-9]{${AppLimits.invitationCodeLength}}\$',
  );

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    final ok = RegExp(r'^\+7\d{10}$').hasMatch(v);
    if (!ok) {
      return 'Некорректный номер телефона';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return 'Введите адрес электронной почты';
    }
    if (v.length > 100) {
      return 'Слишком длинный адрес электронной почты';
    }
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) {
      return 'Некорректный адрес электронной почты';
    }
    return null;
  }

  static String? password(String? value) {
    final v = (value ?? '');
    if (v.length < 6) return 'Слишком короткий пароль';
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpecial = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]=+;`~]',
    ).hasMatch(v);
    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      return 'Пароль должен содержать заглавную букву, строчную букву, цифру и специальный символ';
    }
    return null;
  }

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || v.length > 40 || !_safeTextPattern.hasMatch(v)) {
      return 'Некорректное имя пользователя';
    }
    return null;
  }

  static String? communityName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || v.length > 50 || !_safeTextPattern.hasMatch(v)) {
      return 'Недопустимое название сообщества';
    }
    return null;
  }

  static String? requestTitle(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || v.length > 100 || !_safeTextPattern.hasMatch(v)) {
      return 'Некорректное название запроса';
    }
    return null;
  }

  static String? customCategory(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty ||
        v.length > 40 ||
        !_safeTextPattern.hasMatch(v) ||
        !ServiceCategories.contains(v)) {
      return 'Категория услуги не выбрана или некорректна';
    }
    return null;
  }

  static String? contactDetails(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 5 || v.length > 200) {
      return 'Некорректные контактные данные. Укажите телефон, ссылку или другой способ связи.';
    }
    return null;
  }

  static String? invitationCode(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (!_invitationCodePattern.hasMatch(v)) {
      return 'Некорректный код приглашения';
    }
    return null;
  }

  static String? requestDescription(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.requestDescriptionMaxLength) {
      return 'Описание запроса слишком длинное';
    }
    return null;
  }

  static String? requestAddress(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.requestAddressMaxLength) {
      return 'Адрес выполнения слишком длинный';
    }
    return null;
  }

  static String? communityDescription(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.communityDescriptionMaxLength) {
      return 'Слишком длинное описание сообщества';
    }
    return null;
  }

  static String? profileBio(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.profileBioMaxLength) {
      return 'Описание не должно превышать ${AppLimits.profileBioMaxLength} символов';
    }
    return null;
  }

  static String? reviewText(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.reviewTextMaxLength) {
      return 'Отзыв содержит недопустимое содержание';
    }
    return null;
  }

  static String? responseComment(String? value) {
    final text = (value ?? '').trim();
    if (text.length > AppLimits.responseCommentMaxLength) {
      return 'Комментарий слишком длинный';
    }
    return null;
  }

  static String? rewardAmount(String? value) {
    final text = (value ?? '').trim();
    final amount = int.tryParse(text);
    if (amount == null ||
        amount < AppLimits.rewardMinAmount ||
        amount > AppLimits.rewardMaxAmount) {
      return 'Некорректная сумма вознаграждения';
    }
    return null;
  }

  static String? filterReward(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final amount = int.tryParse(text);
    if (amount == null || amount < 0) {
      return 'Некорректные параметры фильтрации';
    }
    return null;
  }

  static String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+7$digits';
    }
    return input.trim();
  }
}
