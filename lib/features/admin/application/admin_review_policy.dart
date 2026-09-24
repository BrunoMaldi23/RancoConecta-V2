import '../../../shared/models/business.dart';
import '../../../shared/models/profile.dart';

enum AdminReviewAction {
  requestChanges,
  reject,
  publish,
  suspend,
  restore;
}

class AdminReviewPolicy {
  const AdminReviewPolicy();

  bool canPerform({
    required ProfileRole role,
    required BusinessPublicationStatus status,
    required AdminReviewAction action,
  }) {
    if (!role.canReviewBusinesses) {
      return false;
    }

    return switch (action) {
      AdminReviewAction.requestChanges =>
        status == BusinessPublicationStatus.pendingReview,
      AdminReviewAction.reject =>
        status == BusinessPublicationStatus.pendingReview,
      AdminReviewAction.publish =>
        status == BusinessPublicationStatus.pendingReview,
      AdminReviewAction.suspend =>
        status == BusinessPublicationStatus.published,
      AdminReviewAction.restore =>
        status == BusinessPublicationStatus.suspended,
    };
  }
}
