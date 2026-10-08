import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/telemetry/telemetry.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/categories/presentation/categories_screen.dart'
    show categoryIconFor;
import '../../../features/locations/application/location_providers.dart';
import '../../../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../../../features/provider_dashboard/presentation/provider_hub.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../application/business_onboarding_requirements.dart';
import '../data/business_onboarding_repository.dart';

/// Asistente de publicación en 5 pasos (FASE 3.21: solo UI). Tipo →
/// Información → Categoría → Cobertura → Revisión. La lógica de guardado,
/// validación y envío a revisión es la misma de antes.
class ProviderRegistrationScreen extends ConsumerStatefulWidget {
  const ProviderRegistrationScreen({
    super.key,
  });

  @override
  ConsumerState<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends ConsumerState<ProviderRegistrationScreen> {
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
  String? _categoryId;
  String? _error;
  String? _statusMessage;

  BusinessType _businessType = BusinessType.service;

  final Set<String> _subcategoryIds = {};
  final Set<String> _coverageLocationIds = {};

  static const _steps = [
    'Tipo',
    'Información',
    'Categoría',
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
        backgroundColor: RancoColors.canvas,
        appBar: AppBar(
          backgroundColor: RancoColors.canvas,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Publicar negocio',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 380,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RancoColors.primarySoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: RancoColors.forest,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Necesitas iniciar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Inicia sesión para crear, guardar y administrar la publicación de tu negocio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      context.go(
                        '/provider/sign-in?next=/provider/register',
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text(
                      'Iniciar sesión',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: AppBar(
        backgroundColor: RancoColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: _step == 0 ? 'Salir' : 'Paso anterior',
          onPressed: _back,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Publicar negocio',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving || _loading ? null : _saveProgress,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Guardar',
            ),
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const RancoLoadingState(rows: 3, rowHeight: 96)
            : Column(
                children: [
                  _ProgressHeader(
                    step: _step,
                    steps: _steps,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: RancoDurations.normal,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => _typeStep(),
                          1 => _profileStep(),
                          2 => _classificationStep(),
                          3 => _coverageStep(),
                          _ => _reviewStep(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Mensajes del paso (error o "Borrador guardado.") junto a las acciones
  /// que los producen, no lejos en la parte superior.
  Widget _footer({
    required String primaryLabel,
    required VoidCallback? onPrimary,
    IconData primaryIcon = Icons.arrow_forward_rounded,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          _InlineMessage(
            message: _error!,
            error: true,
          ),
        if (_statusMessage != null)
          _InlineMessage(
            message: _statusMessage!,
          ),
        const SizedBox(height: 20),
        _StepActions(
          showBack: _step > 0,
          onBack: _saving ? null : _back,
          primaryLabel: primaryLabel,
          primaryIcon: primaryIcon,
          onPrimary: _saving ? null : onPrimary,
          loading: _saving,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 1
  // ---------------------------------------------------------------------------

  Widget _typeStep() {
    Widget card(
      BusinessType type,
      IconData icon,
      String title,
      String subtitle,
    ) {
      return _TypeCard(
        selected: _businessType == type,
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () {
          _setBusinessType(type);
        },
      );
    }

    return _RegistrationPage(
      title: 'Elige el tipo de negocio',
      subtitle:
          'Define las herramientas y opciones iniciales de tu publicación.',
      footer: _footer(
        primaryLabel: 'Continuar',
        onPrimary: _next,
      ),
      child: RancoResponsiveGrid(
        minItemWidth: 190,
        maxColumns: 3,
        minColumns: 2,
        spacing: 10,
        runSpacing: 10,
        equalHeightRows: true,
        children: [
          card(
            BusinessType.service,
            Icons.handyman_outlined,
            'Servicio',
            'Oficios y atención local.',
          ),
          card(
            BusinessType.commerce,
            Icons.storefront_outlined,
            'Comercio',
            'Tiendas y negocios locales.',
          ),
          card(
            BusinessType.gastronomy,
            Icons.restaurant_outlined,
            'Gastronomía',
            'Restaurantes y comida.',
          ),
          card(
            BusinessType.lodging,
            Icons.bed_outlined,
            'Alojamiento',
            'Cabañas y hospedajes.',
          ),
          card(
            BusinessType.tourism,
            Icons.terrain_outlined,
            'Turismo',
            'Experiencias y actividades.',
          ),
          card(
            BusinessType.emergency,
            Icons.emergency_outlined,
            'Emergencia',
            'Atención urgente.',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 2
  // ---------------------------------------------------------------------------

  Widget _profileStep() {
    return _RegistrationPage(
      title: 'Información del negocio',
      subtitle: 'Los datos principales que verán las personas al encontrarte.',
      footer: _footer(
        primaryLabel: 'Continuar',
        onPrimary: _next,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre comercial',
              hintText: 'Ej. Servicios del Ranco',
              prefixIcon: Icon(
                Icons.store_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Qué ofreces y qué te diferencia.',
              helperText: 'Mínimo 20 caracteres.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          const _GroupTitle(
            title: 'Contacto',
            caption: 'Ingresa al menos teléfono, WhatsApp o correo.',
          ),
          const SizedBox(height: 12),
          _FieldPair(
            first: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
              ),
            ),
            second: TextField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                prefixIcon: Icon(
                  Icons.chat_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldPair(
            first: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo comercial',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                ),
              ),
            ),
            second: TextField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Sitio web o red social',
                helperText: 'Opcional',
                prefixIcon: Icon(
                  Icons.language_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _GroupTitle(title: 'Ubicación'),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección o referencia',
              hintText: 'Sector, calle o referencia',
              prefixIcon: Icon(
                Icons.location_on_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 3
  // ---------------------------------------------------------------------------

  Widget _classificationStep() {
    final categories = ref.watch(categoriesProvider);

    final subcategories = ref.watch(
      subcategoriesProvider(
        _categoryId,
      ),
    );

    return _RegistrationPage(
      title: 'Categoría y actividad',
      subtitle: _businessType == BusinessType.service
          ? 'Elige el rubro principal y los servicios específicos que ofreces.'
          : 'Elige la categoría que mejor representa tu negocio.',
      footer: _footer(
        primaryLabel: 'Continuar',
        onPrimary: _next,
      ),
      child: categories.when(
        data: (items) {
          Category? selected;
          for (final category in items) {
            if (category.id == _categoryId) {
              selected = category;
              break;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryField(
                selected: selected,
                onTap: () async {
                  final picked = await showRancoAdaptiveModal<Category>(
                    context: context,
                    maxWidth: 560,
                    builder: (sheetContext) => _CategoryPickerSheet(
                      categories: items,
                      selectedId: _categoryId,
                    ),
                  );
                  if (picked == null || !mounted) return;
                  if (picked.id == _categoryId) return;
                  setState(() {
                    _categoryId = picked.id;

                    _subcategoryIds.clear();

                    _error = null;
                    _statusMessage = null;
                  });
                },
              ),
              if (_businessType == BusinessType.service &&
                  _categoryId != null) ...[
                const SizedBox(height: 22),
                subcategories.when(
                  data: (services) {
                    if (services.isEmpty) {
                      return const _InfoCard(
                        icon: Icons.info_outline_rounded,
                        title: 'Categoría sin actividad configurada',
                        message:
                            'Esta categoría todavía no tiene servicios asociados. Elige otra o contáctanos.',
                        warning: true,
                      );
                    }

                    if (services.length == 1) {
                      final service = services.single;

                      _scheduleSingleServiceSelection(
                        service,
                      );

                      return _InfoCard(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'Actividad definida',
                        message: service.slug == 'general'
                            ? 'Esta categoría no necesita una selección adicional.'
                            : 'Actividad: ${service.name}.',
                      );
                    }

                    final count = _subcategoryIds.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupTitle(
                          title: 'Servicios que ofreces',
                          caption: 'Selecciona uno o varios.',
                          trailing: count == 0
                              ? null
                              : '$count ${count == 1 ? 'seleccionado' : 'seleccionados'}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: services
                              .map(
                                _serviceChip,
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                  loading: () => const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RancoSkeletonBox(width: 150, height: 36, radius: 18),
                      RancoSkeletonBox(width: 110, height: 36, radius: 18),
                      RancoSkeletonBox(width: 130, height: 36, radius: 18),
                    ],
                  ),
                  error: (
                    error,
                    stackTrace,
                  ) =>
                      _InfoCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'No pudimos cargar los servicios',
                    message: failureMessage(
                      error,
                      'Inténtalo nuevamente en unos segundos.',
                    ),
                    warning: true,
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const RancoSkeletonBox(height: 60, radius: 14),
        error: (
          error,
          stackTrace,
        ) =>
            _InfoCard(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar las categorías',
          message: failureMessage(
            error,
            'Inténtalo nuevamente en unos segundos.',
          ),
          warning: true,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 4
  // ---------------------------------------------------------------------------

  Widget _coverageStep() {
    final locations = ref.watch(locationsProvider);
    final count = _coverageLocationIds.length;

    return _RegistrationPage(
      title: 'Cobertura',
      subtitle: 'Selecciona dónde se ubica o en qué localidades atiendes.',
      footer: _footer(
        primaryLabel: 'Revisar',
        onPrimary: _next,
      ),
      child: locations.when(
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GroupTitle(
                title: 'Selecciona dónde atiendes',
                caption: 'Puedes elegir una o varias localidades.',
                trailing: count == 0
                    ? null
                    : '$count ${count == 1 ? 'localidad seleccionada' : 'localidades seleccionadas'}',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map(
                  (location) {
                    final selected = _coverageLocationIds.contains(
                      location.id,
                    );

                    return FilterChip(
                      selected: selected,
                      showCheckmark: true,
                      avatar: selected
                          ? null
                          : const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                            ),
                      label: Text(
                        location.name,
                      ),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _coverageLocationIds.add(
                              location.id,
                            );
                          } else {
                            _coverageLocationIds.remove(
                              location.id,
                            );
                          }

                          _error = null;
                        });
                      },
                    );
                  },
                ).toList(),
              ),
            ],
          );
        },
        loading: () => const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RancoSkeletonBox(width: 120, height: 36, radius: 18),
            RancoSkeletonBox(width: 96, height: 36, radius: 18),
            RancoSkeletonBox(width: 140, height: 36, radius: 18),
          ],
        ),
        error: (
          error,
          stackTrace,
        ) =>
            _InfoCard(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar las localidades',
          message: locationFailureMessage(
            error,
          ),
          warning: true,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 5
  // ---------------------------------------------------------------------------

  Widget _reviewStep() {
    final draft = _currentDraftSnapshot();

    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    final locations = ref.watch(locationsProvider).valueOrNull ?? const [];

    final subcategories = ref
            .watch(
              subcategoriesProvider(
                _categoryId,
              ),
            )
            .valueOrNull ??
        const [];

    String? categoryName;

    for (final category in categories) {
      if (category.id == _categoryId) {
        categoryName = category.name;
        break;
      }
    }

    final locationNames = locations
        .where(
          (location) => _coverageLocationIds.contains(
            location.id,
          ),
        )
        .map(
          (location) => location.name,
        )
        .toList();

    final selectedServices = subcategories
        .where(
          (service) => _subcategoryIds.contains(
            service.id,
          ),
        )
        .toList();

    final serviceNames = selectedServices
        .where(
          (service) => service.slug.toLowerCase() != 'general',
        )
        .map(
          (service) => service.name,
        )
        .toList();

    final hasGeneralService = selectedServices.any(
      (service) => service.slug.toLowerCase() == 'general',
    );

    final requirements = draft == null
        ? const <OnboardingRequirement>[]
        : const BusinessOnboardingRequirements().evaluate(
            draft,
          );

    final canSubmit = draft != null &&
        _termsAccepted &&
        requirements.every(
          (item) => item.satisfied,
        );

    String? servicesSummary;

    if (serviceNames.isNotEmpty) {
      servicesSummary = serviceNames.join(', ');
    } else if (hasGeneralService) {
      servicesSummary = 'Actividad general';
    }

    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final contactRows = [
      if (text(_phoneController) case final value?) ('Teléfono', value),
      if (text(_whatsappController) case final value?) ('WhatsApp', value),
      if (text(_emailController) case final value?) ('Correo', value),
      if (text(_websiteController) case final value?) ('Sitio web', value),
      if (text(_addressController) case final value?) ('Dirección', value),
    ];
    final ready = requirements.where((item) => item.satisfied).length;

    void edit(int step) {
      setState(() {
        _step = step;
        _error = null;
        _statusMessage = null;
      });
    }

    return _RegistrationPage(
      title: 'Revisa tu publicación',
      subtitle: 'Confirma que todo esté correcto antes de enviarla a revisión.',
      footer: _footer(
        primaryLabel: 'Enviar a revisión',
        primaryIcon: Icons.send_outlined,
        onPrimary: canSubmit ? _submit : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReviewSection(
            title: 'Negocio',
            onEdit: () => edit(1),
            rows: [
              ('Nombre', text(_nameController)),
              ('Tipo', _businessType.label),
              ('Descripción', text(_descriptionController)),
            ],
          ),
          const SizedBox(height: 12),
          _ReviewSection(
            title: 'Actividad',
            onEdit: () => edit(2),
            rows: [
              ('Categoría', categoryName),
              if (_businessType == BusinessType.service)
                ('Servicios', servicesSummary),
            ],
          ),
          const SizedBox(height: 12),
          _ReviewSection(
            title: 'Cobertura',
            onEdit: () => edit(3),
            rows: [
              (
                locationNames.length == 1 ? 'Localidad' : 'Localidades',
                locationNames.isEmpty ? null : locationNames.join(' · '),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReviewSection(
            title: 'Contacto',
            onEdit: () => edit(1),
            rows:
                contactRows.isEmpty ? const [('Contacto', null)] : contactRows,
          ),
          const SizedBox(height: 22),
          _GroupTitle(
            title: 'Requisitos',
            trailing: requirements.isEmpty
                ? null
                : '$ready de ${requirements.length} listos',
          ),
          const SizedBox(height: 8),
          ...requirements.map(
            (requirement) => _RequirementRow(
              satisfied: requirement.satisfied,
              text: requirement.message,
            ),
          ),
          const SizedBox(height: 16),
          _ConfirmTile(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() {
                _termsAccepted = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVIDADES
  // ---------------------------------------------------------------------------

  void _scheduleSingleServiceSelection(
    Subcategory service,
  ) {
    if (_subcategoryIds.length == 1 &&
        _subcategoryIds.contains(
          service.id,
        )) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        if (_categoryId != service.categoryId) {
          return;
        }

        setState(() {
          _subcategoryIds
            ..clear()
            ..add(
              service.id,
            );

          _error = null;
        });
      },
    );
  }

  Widget _serviceChip(
    Subcategory service,
  ) {
    final selected = _subcategoryIds.contains(
      service.id,
    );

    return FilterChip(
      selected: selected,
      label: Text(
        service.name,
      ),
      onSelected: (value) {
        setState(() {
          if (value) {
            _subcategoryIds.add(
              service.id,
            );
          } else {
            _subcategoryIds.remove(
              service.id,
            );
          }

          _error = null;
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CAMBIO TIPO
  // ---------------------------------------------------------------------------

  void _setBusinessType(
    BusinessType type,
  ) {
    if (_businessId != null && type != _businessType) {
      setState(() {
        _error =
            'El tipo de negocio es sensible. Crea otro borrador si necesitas cambiarlo.';
      });

      return;
    }

    setState(() {
      _businessType = type;

      _categoryId = null;

      _subcategoryIds.clear();

      _error = null;
      _statusMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // CARGA BORRADOR
  // ---------------------------------------------------------------------------

  Future<void> _loadExistingDraft() async {
    final activeBusinessId = ref.read(activeProviderBusinessIdProvider);
    final repository = ref.read(
      businessOnboardingRepositoryProvider,
    );
    final result = activeBusinessId == null
        ? await repository.getLatestEditableDraft()
        : await repository.getBusinessDraft(activeBusinessId);

    if (!mounted) {
      return;
    }

    result.when(
      success: (draft) {
        if (draft != null) {
          if (draft.canContinueOnboarding) {
            _applyDraft(
              draft,
            );
          } else {
            _error =
                'Este negocio no se puede editar desde onboarding en su estado actual.';
          }
        }
      },
      failure: (failure) {
        _error = failure.message;
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _applyDraft(
    BusinessDraft draft,
  ) {
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
      ..addAll(
        draft.coverage.map(
          (location) => location.id,
        ),
      );

    _subcategoryIds
      ..clear()
      ..addAll(
        draft.services.map(
          (service) => service.subcategory.id,
        ),
      );

    _termsAccepted = draft.onboardingMetadata['terms_accepted'] == true;

    _step = (draft.onboardingMetadata['last_section'] as num?)?.toInt() ?? 0;

    _step = _step.clamp(
      0,
      _steps.length - 1,
    );
  }

  // ---------------------------------------------------------------------------
  // SNAPSHOT LOCAL
  // ---------------------------------------------------------------------------

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
          .map(
            (id) => Location(
              id: id,
              communeId: '',
              name: id,
              slug: '',
            ),
          )
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
      onboardingMetadata: {
        'terms_accepted': _termsAccepted,
      },
      submittedAt: null,
      changesRequestedNote: null,
    );
  }

  // ---------------------------------------------------------------------------
  // CREAR BORRADOR
  // ---------------------------------------------------------------------------

  Future<bool> _ensureDraft() async {
    if (_businessId != null) {
      return true;
    }

    final name = _nameController.text.trim().isEmpty
        ? 'Nuevo negocio'
        : _nameController.text.trim();

    final result = await ref
        .read(
          businessOnboardingRepositoryProvider,
        )
        .createBusinessDraft(
          businessType: _businessType,
          name: name,
        );

    if (!mounted) {
      return false;
    }

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

  // ---------------------------------------------------------------------------
  // GUARDADO
  // ---------------------------------------------------------------------------

  Future<bool> _saveDraft({
    int? nextStep,
  }) async {
    if (_businessType == BusinessType.service &&
        _step >= 2 &&
        _categoryId != null &&
        _subcategoryIds.isEmpty) {
      setState(() {
        _error = 'Selecciona al menos un servicio para continuar.';
      });

      return false;
    }

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
              .map(
                (id) => ServiceDraftInput(
                  subcategoryId: id,
                ),
              )
              .toList()
          : const [],
      onboardingMetadata: {
        'last_section': nextStep ?? _step,
        'terms_accepted': _termsAccepted,
      },
    );

    final result = await ref
        .read(
          businessOnboardingRepositoryProvider,
        )
        .updateBusinessDraft(
          input,
        );

    if (!mounted) {
      return false;
    }

    return result.when(
      success: (draft) {
        _applyDraft(
          draft,
        );

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

  // ---------------------------------------------------------------------------
  // SIGUIENTE
  // ---------------------------------------------------------------------------

  Future<void> _next() async {
    if (_step >= _steps.length - 1) {
      return;
    }

    if (_step == 1) {
      if (_nameController.text.trim().length < 3) {
        setState(() {
          _error = 'Agrega un nombre comercial válido para continuar.';
        });

        return;
      }
    }

    if (_step == 2) {
      if (_categoryId == null) {
        setState(() {
          _error = 'Selecciona una categoría para continuar.';
        });

        return;
      }

      if (_businessType == BusinessType.service && _subcategoryIds.isEmpty) {
        setState(() {
          _error = 'Selecciona al menos un servicio para continuar.';
        });

        return;
      }
    }

    if (_step == 3 && _coverageLocationIds.isEmpty) {
      setState(() {
        _error = 'Selecciona al menos una localidad para continuar.';
      });

      return;
    }

    final target = _step + 1;

    final saved = await _saveDraft(
      nextStep: target,
    );

    if (!saved || !mounted) {
      return;
    }

    setState(() {
      _step = target;
    });
  }

  // ---------------------------------------------------------------------------
  // VOLVER
  // ---------------------------------------------------------------------------

  void _back() {
    if (_step == 0) {
      context.go(
        '/account',
      );

      return;
    }

    setState(() {
      _step--;
      _error = null;
      _statusMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // ENVIAR REVISIÓN
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_termsAccepted) {
      setState(() {
        _error = 'Confirma que la información es correcta antes de enviarla.';
      });

      return;
    }

    final draft = _currentDraftSnapshot();

    if (draft == null) {
      return;
    }

    final requirements = const BusinessOnboardingRequirements().evaluate(
      draft,
    );

    final missing = requirements
        .where(
          (item) => !item.satisfied,
        )
        .toList();

    if (missing.isNotEmpty) {
      setState(() {
        _error =
            'Completa los requisitos pendientes antes de enviar el negocio.';
      });

      return;
    }

    final saved = await _saveDraft(
      nextStep: _step,
    );

    if (!saved || _businessId == null) {
      return;
    }

    setState(() {
      _saving = true;

      _error = null;
    });

    final result = await ref
        .read(
          businessOnboardingRepositoryProvider,
        )
        .submitBusinessForReview(
          _businessId!,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        Telemetry.capture('provider_register');
        ref.read(activeProviderBusinessIdProvider.notifier).state =
            _businessId!;
        ref.invalidate(
          myProviderBusinessesProvider,
        );
        ref.invalidate(
          activeProviderBusinessProvider,
        );

        context.go(
          providerHubHomeRoute,
        );
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

// =============================================================================
// PROGRESO
// =============================================================================

/// Ancho del contenido del asistente: formulario legible sin zonas muertas.
const _wizardMaxWidth = 760.0;

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.steps,
  });

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${step + 1} de ${steps.length}: ${steps[step]}',
      excludeSemantics: true,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE1EAE5))),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _wizardMaxWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 560) {
                  return _WideStepper(step: step, steps: steps);
                }
                return _CompactStepper(step: step, steps: steps);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WideStepper extends StatelessWidget {
  const _WideStepper({required this.step, required this.steps});

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          if (index > 0)
            Expanded(
              child: AnimatedContainer(
                duration: RancoDurations.quick,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: index <= step
                    ? RancoColors.forest
                    : const Color(0xFFD9E5DF),
              ),
            ),
          _StepDot(index: index, step: step),
          const SizedBox(width: 8),
          Text(
            steps[index],
            style: TextStyle(
              color: index == step
                  ? RancoColors.textPrimary
                  : RancoColors.textSecondary,
              fontSize: 13,
              fontWeight: index == step ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.step});

  final int index;
  final int step;

  @override
  Widget build(BuildContext context) {
    final done = index < step;
    final current = index == step;
    return AnimatedContainer(
      duration: RancoDurations.quick,
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done || current ? RancoColors.forest : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: done || current ? RancoColors.forest : const Color(0xFFCAD8D1),
          width: 1.5,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: current ? Colors.white : RancoColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _CompactStepper extends StatelessWidget {
  const _CompactStepper({required this.step, required this.steps});

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Paso ${step + 1} de ${steps.length} · ',
                style: const TextStyle(color: RancoColors.textSecondary),
              ),
              TextSpan(
                text: steps[step],
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < steps.length; index++)
              Expanded(
                child: AnimatedContainer(
                  duration: RancoDurations.quick,
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index == steps.length - 1 ? 0 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? RancoColors.forest
                        : const Color(0xFFD5E3DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// CONTENIDO DE CADA PASO
// =============================================================================

class _RegistrationPage extends StatelessWidget {
  const _RegistrationPage({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Mensajes + acciones, pegados al final del formulario (no al borde
  /// inferior de la ventana).
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        16,
        22,
        16,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _wizardMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              child,
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACCIONES
// =============================================================================

class _StepActions extends StatelessWidget {
  const _StepActions({
    required this.showBack,
    required this.onBack,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.loading,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      onPressed: loading ? null : onPrimary,
      icon: loading
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(primaryIcon, size: 18),
      label: Text(primaryLabel),
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 48),
        disabledBackgroundColor: const Color(0xFFD9E7E0),
        disabledForegroundColor: const Color(0xFF66766E),
      ),
    );
    final back = OutlinedButton(
      onPressed: onBack,
      style: OutlinedButton.styleFrom(minimumSize: const Size(110, 48)),
      child: const Text('Atrás'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Row(
            children: [
              if (showBack) ...[
                Expanded(flex: 2, child: back),
                const SizedBox(width: 10),
              ],
              Expanded(flex: 3, child: primary),
            ],
          );
        }
        return Row(
          children: [
            if (showBack) back,
            const Spacer(),
            primary,
          ],
        );
      },
    );
  }
}

// =============================================================================
// CAMPOS
// =============================================================================

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;

  /// Contador a la derecha (p. ej. "2 localidades seleccionadas").
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(
            trailing!,
            style: const TextStyle(
              color: RancoColors.primaryDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Dos campos lado a lado en pantallas amplias; apilados en móvil.
class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

// =============================================================================
// TIPO DE NEGOCIO
// =============================================================================

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
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFF0F8F4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: RancoDurations.quick,
            constraints: const BoxConstraints(minHeight: 108),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? RancoColors.forest : const Color(0xFFDCE6E1),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? RancoColors.primaryMuted
                            : const Color(0xFFF1F6F3),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        icon,
                        color: RancoColors.forest,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: RancoColors.forest,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RancoColors.textPrimary,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: RancoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORÍA
// =============================================================================

/// Grupos editoriales del selector. Solo presentación: las categorías y sus
/// datos no cambian.
const categoryPickerGroups = [
  'Turismo',
  'Alojamiento',
  'Gastronomía',
  'Servicios',
  'Emergencias',
  'Otros',
];

/// Grupo editorial de una categoría según su slug, nombre e ícono.
String categoryPickerGroup(Category category) {
  final key =
      '${category.slug} ${category.name} ${category.iconKey}'.toLowerCase();
  if (key.contains('emerg')) return 'Emergencias';
  if (key.contains('turis') || key.contains('aventura')) return 'Turismo';
  if (key.contains('aloj') ||
      key.contains('lodging') ||
      key.contains('caba') ||
      key.contains('hosped')) {
    return 'Alojamiento';
  }
  if (key.contains('gastr') ||
      key.contains('restaur') ||
      key.contains('comida')) {
    return 'Gastronomía';
  }
  if (key.contains('otros') ||
      key.contains('comerc') ||
      key.contains('commerce')) {
    return 'Otros';
  }
  return 'Servicios';
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.selected, required this.onTap});

  final Category? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = selected;
    return Semantics(
      button: true,
      label: category == null
          ? 'Elegir categoría'
          : 'Categoría: ${category.name}. Cambiar',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: category == null
                    ? const Color(0xFFCFDCD5)
                    : RancoColors.forest.withValues(alpha: .55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RancoColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    category == null
                        ? Icons.category_outlined
                        : categoryIconFor(category),
                    color: RancoColors.forest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category == null ? 'Categoría' : category.name,
                        style: TextStyle(
                          color: category == null
                              ? RancoColors.textSecondary
                              : RancoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: category == null
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category == null
                            ? 'Busca y elige la categoría principal'
                            : categoryPickerGroup(category),
                        style: const TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  category == null ? 'Elegir' : 'Cambiar',
                  style: const TextStyle(
                    color: RancoColors.primaryDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RancoColors.primaryDark,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector con búsqueda y grupos editoriales. Devuelve la categoría elegida
/// con `Navigator.pop`.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
  });

  final List<Category> categories;
  final String? selectedId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = [
      for (final category in widget.categories)
        if (query.isEmpty || category.name.toLowerCase().contains(query))
          category,
    ];
    final grouped = <String, List<Category>>{
      for (final group in categoryPickerGroups) group: [],
    };
    for (final category in filtered) {
      grouped[categoryPickerGroup(category)]!.add(category);
    }

    final dialog =
        MediaQuery.sizeOf(context).width >= RancoBreakpoints.expanded;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!dialog)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD7E2DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 10, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Elige una categoría',
                  style: TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            autofocus: dialog,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Buscar categoría',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Text(
                    'No encontramos categorías con ese nombre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RancoColors.textSecondary),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  children: [
                    for (final entry in grouped.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                          child: Semantics(
                            header: true,
                            child: Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(
                                color: RancoColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8,
                              ),
                            ),
                          ),
                        ),
                        for (final category in entry.value)
                          _CategoryOption(
                            category: category,
                            selected: category.id == widget.selectedId,
                            onTap: () => Navigator.of(context).pop(category),
                          ),
                      ],
                  ],
                ),
        ),
      ],
    );

    if (dialog) return content;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? RancoColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    categoryIconFor(category),
                    size: 20,
                    color: RancoColors.forest,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: RancoColors.forest,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REVISIÓN
// =============================================================================

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final String title;

  /// Etiqueta y valor; un valor nulo se muestra como "Pendiente".
  final List<(String, String?)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text('Editar', semanticsLabel: 'Editar $title'),
              ),
            ],
          ),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: _ReviewLine(label: label, value: value),
            ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final pending = value == null || value!.trim().isEmpty;
    final valueText = Text(
      pending ? 'Pendiente' : value!,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: pending ? const Color(0xFF9A3B33) : RancoColors.textPrimary,
        fontSize: 14,
        fontWeight: pending ? FontWeight.w600 : FontWeight.w700,
        height: 1.35,
      ),
    );
    final labelText = Text(
      label,
      style: const TextStyle(
        color: RancoColors.textSecondary,
        fontSize: 13,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelText, const SizedBox(height: 2), valueText],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: labelText),
            const SizedBox(width: 12),
            Expanded(child: valueText),
          ],
        );
      },
    );
  }
}

class _ConfirmTile extends StatelessWidget {
  const _ConfirmTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? const Color(0xFFF0F8F4) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: RancoDurations.quick,
          padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? RancoColors.forest : const Color(0xFFD3E1DA),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmo que la información es correcta',
                        style: TextStyle(
                          color: RancoColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Quiero enviar este negocio a revisión para su publicación inicial.',
                        style: TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TARJETA INFO
// =============================================================================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tone = warning ? const Color(0xFF8A5B12) : RancoColors.primaryDark;
    final background =
        warning ? const Color(0xFFFFF7E9) : const Color(0xFFF1F8F5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REQUISITOS
// =============================================================================

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.satisfied,
    required this.text,
  });

  final bool satisfied;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${satisfied ? 'Listo' : 'Pendiente'}: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              satisfied
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: satisfied ? RancoColors.forest : const Color(0xFFB4543F),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                satisfied ? text.replaceFirst(RegExp(r'\.$'), '') : text,
                style: TextStyle(
                  color: satisfied
                      ? RancoColors.textSecondary
                      : RancoColors.textPrimary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: satisfied ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MENSAJE
// =============================================================================

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    this.error = false,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tone = error ? const Color(0xFF8C2F28) : RancoColors.primaryDark;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFEDEA) : const Color(0xFFE6F3ED),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: tone,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: tone,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
