import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_review_policy.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  const policy = AdminReviewPolicy();

  test('only admin roles can access business review actions', () {
    expect(ProfileRole.admin.canAccessAdmin, isTrue);
    expect(ProfileRole.superAdmin.canAccessAdmin, isTrue);
    expect(ProfileRole.provider.canAccessAdmin, isFalse);
    expect(ProfileRole.customer.canAccessAdmin, isFalse);
  });

  test('admin can request changes and publish pending reviews', () {
    expect(
      policy.canPerform(
        role: ProfileRole.admin,
        status: BusinessPublicationStatus.pendingReview,
        action: AdminReviewAction.requestChanges,
      ),
      isTrue,
    );
    expect(
      policy.canPerform(
        role: ProfileRole.admin,
        status: BusinessPublicationStatus.pendingReview,
        action: AdminReviewAction.publish,
      ),
      isTrue,
    );
  });

  test('normal providers cannot publish or suspend businesses', () {
    expect(
      policy.canPerform(
        role: ProfileRole.provider,
        status: BusinessPublicationStatus.pendingReview,
        action: AdminReviewAction.publish,
      ),
      isFalse,
    );
    expect(
      policy.canPerform(
        role: ProfileRole.provider,
        status: BusinessPublicationStatus.published,
        action: AdminReviewAction.suspend,
      ),
      isFalse,
    );
  });

  test('suspension and restoration transitions are explicit', () {
    expect(
      policy.canPerform(
        role: ProfileRole.admin,
        status: BusinessPublicationStatus.published,
        action: AdminReviewAction.suspend,
      ),
      isTrue,
    );
    expect(
      policy.canPerform(
        role: ProfileRole.admin,
        status: BusinessPublicationStatus.suspended,
        action: AdminReviewAction.restore,
      ),
      isTrue,
    );
    expect(
      policy.canPerform(
        role: ProfileRole.admin,
        status: BusinessPublicationStatus.published,
        action: AdminReviewAction.restore,
      ),
      isFalse,
    );
  });

  test('public visibility is limited to published businesses', () {
    expect(BusinessPublicationStatus.published.isPubliclyVisible, isTrue);
    expect(BusinessPublicationStatus.draft.isPubliclyVisible, isFalse);
    expect(BusinessPublicationStatus.pendingReview.isPubliclyVisible, isFalse);
    expect(BusinessPublicationStatus.suspended.isPubliclyVisible, isFalse);
  });
}
