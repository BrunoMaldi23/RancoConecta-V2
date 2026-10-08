bool isValidChileanPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return (digits.length == 9 && RegExp(r'^[2-9]').hasMatch(digits)) ||
      (digits.length == 11 && RegExp(r'^56[2-9]').hasMatch(digits));
}
