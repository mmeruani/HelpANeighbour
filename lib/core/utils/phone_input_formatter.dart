import 'package:flutter/services.dart';

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final normalized = digits.startsWith('8')
        ? '7${digits.substring(1)}'
        : digits.startsWith('7')
            ? digits
            : '7$digits';
    final trimmed = normalized.substring(
      0,
      normalized.length > 11 ? 11 : normalized.length,
    );

    final buffer = StringBuffer('+7');
    if (trimmed.length > 1) {
      buffer.write(' (');
      buffer.write(trimmed.substring(1, trimmed.length.clamp(1, 4)));
    }
    if (trimmed.length >= 4) {
      buffer.write(') ');
      buffer.write(trimmed.substring(4, trimmed.length.clamp(4, 7)));
    }
    if (trimmed.length >= 7) {
      buffer.write('-');
      buffer.write(trimmed.substring(7, trimmed.length.clamp(7, 9)));
    }
    if (trimmed.length >= 9) {
      buffer.write('-');
      buffer.write(trimmed.substring(9, trimmed.length.clamp(9, 11)));
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
