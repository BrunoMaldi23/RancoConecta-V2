import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/core/utils/chilean_phone.dart';
import 'package:ranco_conecta_2/core/utils/idempotency_key.dart';

void main() {
  group('anonymous customer submission contracts', () {
    test('accepts common Chilean mobile and landline formats', () {
      expect(isValidChileanPhone('+56 9 1234 5678'), isTrue);
      expect(isValidChileanPhone('912345678'), isTrue);
      expect(isValidChileanPhone('+56 2 2345 6789'), isTrue);
      expect(isValidChileanPhone('223456789'), isTrue);
    });

    test('rejects too short, malformed, or non-Chilean numbers', () {
      expect(isValidChileanPhone('1234'), isFalse);
      expect(isValidChileanPhone('+1 202 555 0100'), isFalse);
      expect(isValidChileanPhone('569123'), isFalse);
    });

    test('idempotency keys are UUID v4 values', () {
      expect(
        newIdempotencyKey(),
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        )),
      );
    });
  });
}
