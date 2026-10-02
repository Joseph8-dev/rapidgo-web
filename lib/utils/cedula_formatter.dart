import 'package:flutter/services.dart';

class CedulaInputFormatter extends TextInputFormatter {
  const CedulaInputFormatter({this.defaultPrefix = 'V'});

  final String defaultPrefix;

  static const String _letters = 'VEJPG';
  static const int _maxDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase();

    if (raw.isEmpty || (oldValue.text.length > raw.length && raw.length <= 2 && !raw.contains(RegExp(r'\d')))) {
      return const TextEditingValue(text: '');
    }

    final letter = _letters.contains(raw[0]) ? raw[0] : defaultPrefix;
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) {
      final text = '$letter-';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    final trimmed =
        digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits;
    final text = '$letter-$trimmed';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  static String normalize(String value, {String defaultPrefix = 'V'}) {
    final raw = value.trim().toUpperCase();
    if (raw.isEmpty) return '';
    final letter = _letters.contains(raw.isEmpty ? '' : raw[0]) ? raw[0] : defaultPrefix;
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return '';
    return '$letter-${digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits}';
  }

  static bool isComplete(String value) =>
      RegExp('^[$_letters]-\\d{5,$_maxDigits}\$').hasMatch(value.trim().toUpperCase());
}
