import '../../../shared/models/business.dart';
import '../data/business_onboarding_repository.dart';

class OnboardingRequirement {
  const OnboardingRequirement({
    required this.key,
    required this.satisfied,
    required this.message,
  });

  final String key;
  final bool satisfied;
  final String message;
}

class BusinessOnboardingRequirements {
  const BusinessOnboardingRequirements();

  List<OnboardingRequirement> evaluate(BusinessDraft draft) {
    return [
      OnboardingRequirement(
        key: 'name',
        satisfied: draft.name.trim().length >= 3,
        message: 'Agrega el nombre comercial.',
      ),
      OnboardingRequirement(
        key: 'description',
        satisfied: (draft.description ?? '').trim().length >= 20,
        message: 'Agrega una descripción más completa.',
      ),
      OnboardingRequirement(
        key: 'category',
        satisfied: draft.primaryCategoryId != null,
        message: 'Selecciona una categoría.',
      ),
      OnboardingRequirement(
        key: 'contact',
        satisfied: [
          draft.phone,
          draft.whatsapp,
          draft.email,
        ].any((value) => (value ?? '').trim().isNotEmpty),
        message: 'Agrega teléfono, WhatsApp o email.',
      ),
      OnboardingRequirement(
        key: 'coverage',
        satisfied: draft.coverage.isNotEmpty,
        message: 'Selecciona al menos una localidad.',
      ),
      if (draft.businessType == BusinessType.service)
        OnboardingRequirement(
          key: 'service_items',
          satisfied: draft.services.isNotEmpty,
          message: 'Selecciona al menos un servicio.',
        ),
    ];
  }

  bool canSubmit(BusinessDraft draft) {
    return evaluate(draft).every((requirement) => requirement.satisfied);
  }
}
