import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';
import '../application/business_onboarding_requirements.dart';
import '../data/business_onboarding_repository.dart';

class ProviderRegistrationScreen extends ConsumerStatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  ConsumerState<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends ConsumerState<ProviderRegistrationScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();

  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _termsAccepted = false;
  String? _businessId;
  String? _error;
  String? _statusMessage;

  BusinessType _businessType = BusinessType.service;
  String? _categoryId;
  final Set<String> _subcategoryIds = {};
  final Set<String> _coverageLocationIds = {};

  static const _steps = [
    'Tipo',
    'Perfil',
    'Clasificación',
    'Cobertura',
    'Revisión',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingDraft();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser();

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEAF4F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFEAF4F0),
          title: const Text('Publicar negocio'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: RancoColors.forest,
                  size: 42,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Inicia sesión para crear un negocio.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF4F0),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Crear negocio'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProgress,
            child: const Text('Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _ProgressHeader(step: _step, steps: _steps),
                      if (_error != null)
                        _InlineMessage(message: _error!, error: true),
                      if (_statusMessage != null)
                        _InlineMessage(message: _statusMessage!),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _typeStep(),
                            _profileStep(),
                            _classificationStep(),
                            _coverageStep(),
                            _reviewStep(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _typeStep() {
    return _RegistrationPage(
      title: 'Elige el tipo de negocio',
      subtitle: 'Esto define las capacidades iniciales del negocio.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _TypeCard(
                selected: _businessType == BusinessType.service,
                icon: Icons.handyman_outlined,
                title: 'Servicio',
                subtitle: 'Oficios, mantención, fletes y atención local.',
                onTap: () => _setBusinessType(BusinessType.service),
              ),
              _TypeCard(
                selected: _businessType == BusinessType.commerce,
                icon: Icons.storefront_outlined,
                title: 'Comercio',
                subtitle: 'Tiendas, almacenes y negocios locales.',
                onTap: () => _setBusinessType(BusinessType.commerce),
              ),
              _TypeCard(
                selected: _businessType == BusinessType.gastronomy,
                icon: Icons.restaurant_outlined,
                title: 'Gastronomía',
                subtitle: 'Restaurantes, cafeterías y comida preparada.',
                onTap: () => _setBusinessType(BusinessType.gastronomy),
              ),
              _TypeCard(
                selected: _businessType == BusinessType.lodging,
                icon: Icons.bed_outlined,
                title: 'Alojamiento',
                subtitle: 'Cabañas, hoteles, hostales y hospedajes.',
                onTap: () => _setBusinessType(BusinessType.lodging),
              ),
              _TypeCard(
                selected: _businessType == BusinessType.tourism,
                icon: Icons.terrain_outlined,
                title: 'Turismo',
                subtitle: 'Tours, experiencias y actividades.',
                onTap: () => _setBusinessType(BusinessType.tourism),
              ),
              _TypeCard(
                selected: _businessType == BusinessType.emergency,
                icon: Icons.emergency_outlined,
                title: 'Emergencia',
                subtitle: 'Atención urgente y disponibilidad.',
                onTap: () => _setBusinessType(BusinessType.emergency),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _NextButton(text: 'Continuar', loading: _saving, onPressed: _next),
        ],
      ),
    );
  }

  Widget _profileStep() {
    return _RegistrationPage(
      title: 'Perfil común',
      subtitle: 'Esta información queda guardada como borrador.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Nombre comercial'),
          const SizedBox(height: 7),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Ej. Servicios del Ranco',
              prefixIcon: Icon(Icons.store_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Descripción'),
          const SizedBox(height: 7),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Describe qué ofrece tu negocio.',
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Contacto'),
          const SizedBox(height: 7),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'WhatsApp',
              prefixIcon: Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email comercial',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _websiteController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'Sitio web o red social',
              prefixIcon: Icon(Icons.language_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Dirección o referencia'),
          const SizedBox(height: 7),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Sector, calle o referencia',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 24),
          _NextButton(
            text: 'Guardar y continuar',
            loading: _saving,
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _classificationStep() {
    final categories = ref.watch(categoriesProvider);
    final subcategories = ref.watch(subcategoriesProvider(_categoryId));

    return _RegistrationPage(
      title: 'Clasificación',
      subtitle: _businessType == BusinessType.service
          ? 'Selecciona categoría y servicios ofrecidos.'
          : 'Selecciona la categoría principal del negocio.',
      child: categories.when(
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: items
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                    _subcategoryIds.clear();
                  });
                },
              ),
              if (_businessType == BusinessType.service) ...[
                const SizedBox(height: 18),
                subcategories.when(
                  data: (services) {
                    if (_categoryId == null) {
                      return const Text('Selecciona una categoría primero.');
                    }

                    if (services.isEmpty) {
                      return const Text('No hay servicios disponibles.');
                    }

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: services.map(_serviceChip).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    failureMessage(error, 'No pudimos cargar servicios.'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _NextButton(
                text: 'Guardar y continuar',
                loading: _saving,
                onPressed: _next,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(
          failureMessage(error, 'No pudimos cargar categorías.'),
        ),
      ),
    );
  }

  Widget _coverageStep() {
    final locations = ref.watch(locationsProvider);

    return _RegistrationPage(
      title: 'Cobertura y localidad',
      subtitle: 'Selecciona donde opera o se ubica el negocio.',
      child: locations.when(
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((location) {
                  final selected = _coverageLocationIds.contains(location.id);

                  return FilterChip(
                    selected: selected,
                    avatar: const Icon(Icons.location_on_outlined, size: 17),
                    label: Text(location.name),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _coverageLocationIds.add(location.id);
                        } else {
                          _coverageLocationIds.remove(location.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
                title: const Text('Acepto enviar esta información a revisión'),
                subtitle: const Text(
                  'La publicación gratuita queda sujeta a aprobación inicial.',
                ),
              ),
              const SizedBox(height: 24),
              _NextButton(
                text: 'Guardar y revisar',
                loading: _saving,
                onPressed: _next,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(locationFailureMessage(error)),
      ),
    );
  }

  Widget _reviewStep() {
    final draft = _currentDraftSnapshot();
    final requirements = draft == null
        ? const <OnboardingRequirement>[]
        : const BusinessOnboardingRequirements().evaluate(draft);
    final canSubmit = draft != null &&
        _termsAccepted &&
        requirements.every((item) => item.satisfied);

    return _RegistrationPage(
      title: 'Enviar a revisión',
      subtitle: 'Revisa los requisitos mínimos antes de enviar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(
            rows: [
              _SummaryRow('Tipo', _businessType.label),
              _SummaryRow('Nombre', _nameController.text),
              _SummaryRow(
                'Categoría',
                _categoryId == null ? 'Pendiente' : 'Seleccionada',
              ),
              _SummaryRow(
                'Servicios',
                '${_subcategoryIds.length} seleccionados',
              ),
              _SummaryRow(
                'Localidades',
                '${_coverageLocationIds.length} seleccionadas',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...requirements.map(
            (requirement) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                requirement.satisfied
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: requirement.satisfied
                    ? RancoColors.forest
                    : const Color(0xFFB4543F),
              ),
              title: Text(requirement.message),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _termsAccepted ? Icons.check_circle_outline : Icons.error_outline,
              color:
                  _termsAccepted ? RancoColors.forest : const Color(0xFFB4543F),
            ),
            title: const Text('Acepta el envío a revisión.'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: canSubmit && !_saving ? _submit : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar a revisión'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: RancoColors.forest,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceChip(Subcategory service) {
    final selected = _subcategoryIds.contains(service.id);

    return FilterChip(
      selected: selected,
      label: Text(service.name),
      onSelected: (value) {
        setState(() {
          if (value) {
            _subcategoryIds.add(service.id);
          } else {
            _subcategoryIds.remove(service.id);
          }
        });
      },
    );
  }

  void _setBusinessType(BusinessType type) {
    if (_businessId != null && type != _businessType) {
      setState(() {
        _error =
            'El tipo de negocio es sensible. Crea otro borrador si necesitas cambiarlo.';
      });
      return;
    }

    setState(() {
      _businessType = type;
    });
  }

  Future<void> _loadExistingDraft() async {
    final result = await ref
        .read(businessOnboardingRepositoryProvider)
        .getLatestEditableDraft();

    if (!mounted) return;

    result.when(
      success: (draft) {
        if (draft != null) {
          _applyDraft(draft);
        }
      },
      failure: (failure) {
        _error = failure.message;
      },
    );

    setState(() {
      _loading = false;
    });
  }

  void _applyDraft(BusinessDraft draft) {
    _businessId = draft.id;
    _businessType = draft.businessType;
    _nameController.text = draft.name;
    _descriptionController.text = draft.description ?? '';
    _phoneController.text = draft.phone ?? '';
    _whatsappController.text = draft.whatsapp ?? '';
    _emailController.text = draft.email ?? '';
    _websiteController.text = draft.website ?? '';
    _addressController.text = draft.addressText ?? '';
    _categoryId = draft.primaryCategoryId;
    _coverageLocationIds
      ..clear()
      ..addAll(draft.coverage.map((location) => location.id));
    _subcategoryIds
      ..clear()
      ..addAll(draft.services.map((service) => service.subcategory.id));
    _termsAccepted = draft.onboardingMetadata['terms_accepted'] == true;
    _step = (draft.onboardingMetadata['last_section'] as num?)?.toInt() ?? 0;
    _step = _step.clamp(0, _steps.length - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_step);
      }
    });
  }

  BusinessDraft? _currentDraftSnapshot() {
    final id = _businessId;

    if (id == null) {
      return null;
    }

    return BusinessDraft(
      id: id,
      businessType: _businessType,
      publicationStatus: BusinessPublicationStatus.draft,
      name: _nameController.text,
      description: _descriptionController.text,
      phone: _phoneController.text,
      whatsapp: _whatsappController.text,
      email: _emailController.text,
      website: _websiteController.text,
      primaryCategoryId: _categoryId,
      addressText: _addressController.text,
      coverage: _coverageLocationIds
          .map((id) => Location(id: id, communeId: '', name: id, slug: ''))
          .toList(),
      services: _subcategoryIds
          .map(
            (id) => BusinessDraftService(
              subcategory: Subcategory(
                id: id,
                categoryId: _categoryId ?? '',
                name: id,
                slug: '',
                description: null,
                iconKey: 'tools',
              ),
              description: null,
              priceFrom: null,
            ),
          )
          .toList(),
      onboardingMetadata: {'terms_accepted': _termsAccepted},
      submittedAt: null,
      changesRequestedNote: null,
    );
  }

  Future<bool> _ensureDraft() async {
    if (_businessId != null) {
      return true;
    }

    final name = _nameController.text.trim().isEmpty
        ? 'Nuevo negocio'
        : _nameController.text.trim();
    final result = await ref
        .read(businessOnboardingRepositoryProvider)
        .createBusinessDraft(
          businessType: _businessType,
          name: name,
        );

    return result.when(
      success: (id) {
        _businessId = id;
        return true;
      },
      failure: (failure) {
        setState(() {
          _error = failure.message;
        });
        return false;
      },
    );
  }

  Future<bool> _saveDraft({int? nextStep}) async {
    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = null;
    });

    final hasDraft = await _ensureDraft();

    if (!hasDraft) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
      return false;
    }

    final input = BusinessDraftInput(
      businessId: _businessId!,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      phone: _phoneController.text.trim(),
      whatsapp: _whatsappController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      primaryCategoryId: _categoryId,
      addressText: _addressController.text.trim(),
      coverageLocationIds: _coverageLocationIds.toList(),
      serviceItems: _businessType == BusinessType.service
          ? _subcategoryIds
              .map((id) => ServiceDraftInput(subcategoryId: id))
              .toList()
          : const [],
      onboardingMetadata: {
        'last_section': nextStep ?? _step,
        'terms_accepted': _termsAccepted,
      },
    );

    final result = await ref
        .read(businessOnboardingRepositoryProvider)
        .updateBusinessDraft(
          input,
        );

    if (!mounted) {
      return false;
    }

    return result.when(
      success: (draft) {
        _applyDraft(draft);
        setState(() {
          _saving = false;
          _statusMessage = 'Borrador guardado.';
        });
        return true;
      },
      failure: (failure) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
        return false;
      },
    );
  }

  Future<void> _saveProgress() async {
    await _saveDraft();
  }

  Future<void> _next() async {
    if (_step >= _steps.length - 1) {
      return;
    }

    final target = _step + 1;
    final saved = await _saveDraft(nextStep: target);

    if (!saved || !mounted) {
      return;
    }

    setState(() {
      _step = target;
    });

    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) {
      context.go('/provider/join');
      return;
    }

    setState(() {
      _step--;
    });

    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    final saved = await _saveDraft(nextStep: _step);

    if (!saved || _businessId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(businessOnboardingRepositoryProvider)
        .submitBusinessForReview(_businessId!);

    if (!mounted) return;

    result.when(
      success: (_) {
        ref.invalidate(myProviderBusinessesProvider);
        context.go('/provider/status');
      },
      failure: (failure) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.steps});

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(
                    right: index == steps.length - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? RancoColors.forest
                        : const Color(0xFFD5E3DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Paso ${step + 1} de ${steps.length} · ${steps[step]}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7D75),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationPage extends StatelessWidget {
  const _RegistrationPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: RancoColors.forest,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7D75),
                ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF50665D),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.text,
    required this.onPressed,
    required this.loading,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(text),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: RancoColors.forest,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F8F4) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? RancoColors.forest : const Color(0xFFD5E2DC),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: RancoColors.forest),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF31443B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF708179),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});

  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E4DE)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.label,
                        style: const TextStyle(color: Color(0xFF708179)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value.isEmpty ? 'Pendiente' : row.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFE8E5) : const Color(0xFFE1F0EA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: error ? const Color(0xFF8C2F28) : RancoColors.forest,
          ),
        ),
      ),
    );
  }
}
