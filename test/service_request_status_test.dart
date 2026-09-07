import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/shared/models/service_request_status.dart';

void main() {
  test('only submitted or viewed requests can receive quotes', () {
    expect(ServiceRequestStatus.submitted.canReceiveQuote, isTrue);
    expect(ServiceRequestStatus.viewed.canReceiveQuote, isTrue);
    expect(ServiceRequestStatus.draft.canReceiveQuote, isFalse);
    expect(ServiceRequestStatus.completed.canReceiveQuote, isFalse);
  });
}
