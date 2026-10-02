class Money implements Comparable<Money> {
  const Money(this.cents);

  final int cents;

  static const Money zero = Money(0);

  factory Money.parse(Object? value) {
    if (value == null) return zero;
    if (value is Money) return value;
    if (value is int) return Money(value * 100);
    if (value is double) return Money((value * 100).round());

    final s = value.toString().trim();
    if (s.isEmpty) return zero;

    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
    if (match == null) {
      final d = double.tryParse(s);
      if (d == null) return zero;
      return Money((d * 100).round());
    }
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.parse(match.group(2)!);
    final frac = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    return Money(sign * (whole * 100 + frac));
  }

  factory Money.fromNum(num bolivares) => Money((bolivares * 100).round());

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money operator *(int qty) => Money(cents * qty);

  bool operator >(Money other) => cents > other.cents;
  bool operator <(Money other) => cents < other.cents;
  bool operator >=(Money other) => cents >= other.cents;
  bool operator <=(Money other) => cents <= other.cents;

  bool get isZero => cents == 0;
  bool get isPositive => cents > 0;

  String toWire() {
    final neg = cents < 0;
    final abs = cents.abs();
    return '${neg ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  String bs({bool symbol = true}) => format(symbol: symbol ? 'Bs ' : '');

  String usdHint(double? rate) {
    if (rate == null || rate <= 0) return '';
    final usd = (cents / 100) / rate;
    return '≈ \$${usd.toStringAsFixed(2)}';
  }

  String usdEstimate(double? rate) {
    if (rate == null || rate <= 0) return '';
    return '\$${((cents / 100) / rate).toStringAsFixed(2)}';
  }

  static Money? parseInput(String raw) {
    var text = raw.trim().replaceAll(RegExp(r'[^0-9.,-]'), '');
    if (text.isEmpty) return null;

    final neg = text.startsWith('-');
    if (neg) text = text.substring(1);

    final lastDot = text.lastIndexOf('.');
    final lastComma = text.lastIndexOf(',');
    String digits;
    String frac = '';

    if (lastDot < 0 && lastComma < 0) {
      digits = text;
    } else {
      final cut = lastDot > lastComma ? lastDot : lastComma;
      final tail = text.substring(cut + 1);
      if (tail.length == 3 || tail.isEmpty) {
        digits = text.replaceAll(RegExp(r'[.,]'), '');
      } else {
        digits = text.substring(0, cut).replaceAll(RegExp(r'[.,]'), '');
        frac = tail.replaceAll(RegExp(r'[^0-9]'), '');
      }
    }

    if (digits.isEmpty && frac.isEmpty) return null;
    final whole = int.tryParse(digits.isEmpty ? '0' : digits);
    if (whole == null) return null;
    final centavos = int.tryParse(frac.padRight(2, '0').substring(0, 2).padLeft(2, '0')) ?? 0;
    final value = whole * 100 + centavos;
    return Money(neg ? -value : value);
  }

  String format({String symbol = 'Bs '}) {
    final neg = cents < 0;
    final abs = cents.abs();
    final whole = (abs ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write('.');
      buf.write(whole[i]);
    }
    return '${neg ? '-' : ''}$symbol$buf,${(abs % 100).toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();
}
