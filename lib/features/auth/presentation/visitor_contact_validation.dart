bool isValidChileanWhatsapp(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty || !RegExp(r'^\+?[0-9\s()\-]+$').hasMatch(input)) {
    return false;
  }

  final digits = input.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^9\d{8}$').hasMatch(digits) ||
      RegExp(r'^569\d{8}$').hasMatch(digits);
}

String? validateVisitorWhatsapp(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'Ingresa tu WhatsApp para que el negocio pueda responderte.';
  }
  if (!isValidChileanWhatsapp(value)) {
    return 'Ingresa un WhatsApp chileno: +56 9 XXXX XXXX.';
  }
  return null;
}
