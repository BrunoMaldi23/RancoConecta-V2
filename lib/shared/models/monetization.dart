import 'business.dart';
import 'business_capability.dart';
import 'operation.dart';

enum BillingPeriod {
  none,
  monthly,
  yearly;
}

class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.businessType,
    required this.name,
    required this.billingPeriod,
    required this.active,
    this.displayOrder = 0,
    this.features = const [],
    this.metadata = const {},
  });

  final String id;
  final BusinessType businessType;
  final String name;
  final BillingPeriod billingPeriod;
  final bool active;
  final int displayOrder;
  final List<PlanFeature> features;
  final Map<String, Object?> metadata;
}

class CommissionRule {
  const CommissionRule({
    required this.businessType,
    required this.operationType,
    required this.active,
    this.percentageBasisPoints,
    this.fixedFee,
    this.minimumFee,
    this.maximumFee,
  });

  final BusinessType businessType;
  final OperationType operationType;
  final bool active;
  final int? percentageBasisPoints;
  final int? fixedFee;
  final int? minimumFee;
  final int? maximumFee;
}

class MonetizationPolicy {
  const MonetizationPolicy({
    required this.capabilities,
    required this.plan,
    required this.commissionRule,
  });

  final BusinessCapabilitySet capabilities;
  final MembershipPlan? plan;
  final CommissionRule? commissionRule;
}

class MonetizationPolicyService {
  const MonetizationPolicyService({
    required this.capabilityResolver,
  });

  final BusinessCapabilityResolver capabilityResolver;

  MonetizationPolicy resolve({
    required BusinessType businessType,
    OperationType? operationType,
    MembershipPlan? currentPlan,
    Iterable<CommissionRule> commissionRules = const [],
  }) {
    final matchingRule = operationType == null
        ? null
        : commissionRules.where((rule) {
            return rule.active &&
                rule.businessType == businessType &&
                rule.operationType == operationType;
          }).firstOrNull;

    return MonetizationPolicy(
      capabilities: capabilityResolver.resolve(
        businessType: businessType,
        planFeatures: currentPlan?.features ?? const [],
      ),
      plan: currentPlan,
      commissionRule: matchingRule,
    );
  }
}
