import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/shared/models/business_membership.dart';
import 'package:ranco_conecta_2/shared/models/operation.dart';

void main() {
  test('parses operation statuses using database values', () {
    expect(
      OperationStatus.parse('in_progress'),
      OperationStatus.inProgress,
    );

    expect(
      OperationStatus.inProgress.value,
      'in_progress',
    );

    expect(
      OperationStatus.parse('unknown'),
      OperationStatus.draft,
    );
  });

  test('keeps unset payment status as not required', () {
    expect(
      OperationPaymentStatus.parse('not_required'),
      OperationPaymentStatus.notRequired,
    );

    expect(
      OperationPaymentStatus.notRequired.value,
      'not_required',
    );
  });

  test('limits local business management permissions to owner and manager', () {
    expect(BusinessMemberRole.owner.canManageBusiness, isTrue);
    expect(BusinessMemberRole.manager.canManageBusiness, isTrue);
    expect(BusinessMemberRole.staff.canManageBusiness, isFalse);
  });
}
