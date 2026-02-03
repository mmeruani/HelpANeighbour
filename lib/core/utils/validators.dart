class Validators {
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
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]=+;`~]').hasMatch(v);
    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      return 'Пароль должен содержать заглавную, строчную, цифру и спецсимвол';
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
