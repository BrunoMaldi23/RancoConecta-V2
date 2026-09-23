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
  const ProviderRegistrationScreen({
    super.key,
  });

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
  String? _categoryId;
  String? _error;
  String? _statusMessage;

  BusinessType _businessType = BusinessType.service;

  final Set<String> _subcategoryIds = {};
  final Set<String> _coverageLocationIds = {};

  static const _steps = [
    'Tipo',
    'Información',
    'Actividad',
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
                      color: const Color(0xFFE5F2EC),
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Inicia sesión para crear, guardar y administrar la publicación de tu negocio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        context.go(
                          '/sign-in?next=/provider/register',
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Iniciar sesión',
                      ),
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
          onPressed: _back,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Crear negocio',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProgress,
            child: const Text(
              'Guardar',
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 680,
            ),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Column(
                    children: [
                      _ProgressHeader(
                        step: _step,
                        steps: _steps,
                      ),
                      if (_error != null)
                        _InlineMessage(
                          message: _error!,
                          error: true,
                        ),
                      if (_statusMessage != null)
                        _InlineMessage(
                          message: _statusMessage!,
                        ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics:
                              const NeverScrollableScrollPhysics(),
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

  // ---------------------------------------------------------------------------
  // PASO 1
  // ---------------------------------------------------------------------------

  Widget _typeStep() {
    return _RegistrationPage(
      title: 'Elige el tipo de negocio',
      subtitle:
          'Esto define las herramientas y opciones iniciales de tu publicación.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 620 ? 3 : 2;

              return GridView.count(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio:
                    constraints.maxWidth >= 620
                        ? 1.75
                        : 1.42,
                children: [
                  _TypeCard(
                    selected:
                        _businessType == BusinessType.service,
                    icon: Icons.handyman_outlined,
                    title: 'Servicio',
                    subtitle: 'Oficios y atención local.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.service,
                      );
                    },
                  ),
                  _TypeCard(
                    selected:
                        _businessType == BusinessType.commerce,
                    icon: Icons.storefront_outlined,
                    title: 'Comercio',
                    subtitle:
                        'Tiendas y negocios locales.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.commerce,
                      );
                    },
                  ),
                  _TypeCard(
                    selected:
                        _businessType ==
                            BusinessType.gastronomy,
                    icon: Icons.restaurant_outlined,
                    title: 'Gastronomía',
                    subtitle:
                        'Restaurantes y comida.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.gastronomy,
                      );
                    },
                  ),
                  _TypeCard(
                    selected:
                        _businessType ==
                            BusinessType.lodging,
                    icon: Icons.bed_outlined,
                    title: 'Alojamiento',
                    subtitle:
                        'Cabañas y hospedajes.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.lodging,
                      );
                    },
                  ),
                  _TypeCard(
                    selected:
                        _businessType ==
                            BusinessType.tourism,
                    icon: Icons.terrain_outlined,
                    title: 'Turismo',
                    subtitle:
                        'Experiencias y actividades.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.tourism,
                      );
                    },
                  ),
                  _TypeCard(
                    selected:
                        _businessType ==
                            BusinessType.emergency,
                    icon: Icons.emergency_outlined,
                    title: 'Emergencia',
                    subtitle: 'Atención urgente.',
                    onTap: () {
                      _setBusinessType(
                        BusinessType.emergency,
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _NextButton(
            text: 'Continuar',
            loading: _saving,
            onPressed: _next,
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
      subtitle:
          'Completa los datos principales que verán las personas al encontrar tu publicación.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label(
            'Nombre comercial',
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _nameController,
            textCapitalization:
                TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Ej. Servicios del Ranco',
              prefixIcon: Icon(
                Icons.store_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Label(
            'Descripción',
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Cuenta brevemente qué ofrece tu negocio y qué lo diferencia.',
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHint(
            icon: Icons.call_outlined,
            title: 'Contacto',
            message:
                'Debes ingresar al menos teléfono, WhatsApp o correo comercial.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Teléfono',
              prefixIcon: Icon(
                Icons.phone_outlined,
              ),
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'WhatsApp',
              prefixIcon: Icon(
                Icons.chat_outlined,
              ),
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _emailController,
            keyboardType:
                TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email comercial',
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
              ),
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _websiteController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText:
                  'Sitio web o red social (opcional)',
              prefixIcon: Icon(
                Icons.language_outlined,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Label(
            'Dirección o referencia',
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText:
                  'Sector, calle o referencia',
              prefixIcon: Icon(
                Icons.location_on_outlined,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _NextButton(
            text: 'Guardar y continuar',
            loading: _saving,
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 3
  // ---------------------------------------------------------------------------

  Widget _classificationStep() {
    final categories =
        ref.watch(categoriesProvider);

    final subcategories =
        ref.watch(
      subcategoriesProvider(
        _categoryId,
      ),
    );

    return _RegistrationPage(
      title: 'Categoría y actividad',
      subtitle:
          _businessType == BusinessType.service
              ? 'Elige el rubro principal y, cuando corresponda, los servicios específicos.'
              : 'Elige la categoría principal que mejor representa tu negocio.',
      child: categories.when(
        data: (items) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(
                    Icons.category_outlined,
                  ),
                ),
                items: items
                    .map(
                      (category) =>
                          DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;

                    _subcategoryIds.clear();

                    _error = null;
                    _statusMessage = null;
                  });
                },
              ),
              if (_businessType ==
                  BusinessType.service) ...[
                const SizedBox(height: 16),
                subcategories.when(
                  data: (services) {
                    if (_categoryId == null) {
                      return const _InfoCard(
                        icon:
                            Icons.category_outlined,
                        title:
                            'Selecciona una categoría',
                        message:
                            'Después podrás definir la actividad específica de tu negocio.',
                      );
                    }

                    if (services.isEmpty) {
                      return const _InfoCard(
                        icon:
                            Icons.info_outline_rounded,
                        title:
                            'Categoría sin actividad configurada',
                        message:
                            'Esta categoría todavía no tiene una actividad asociada en la base de datos.',
                        warning: true,
                      );
                    }

                    if (services.length == 1) {
                      final service =
                          services.single;

                      _scheduleSingleServiceSelection(
                        service,
                      );

                      return _InfoCard(
                        icon: Icons
                            .check_circle_outline_rounded,
                        title:
                            'Actividad definida',
                        message:
                            service.slug == 'general'
                                ? 'Esta categoría no necesita una selección adicional.'
                                : 'Actividad: ${service.name}.',
                      );
                    }

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const _Label(
                          'Servicios que ofreces',
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Selecciona uno o varios.',
                          style: TextStyle(
                            color: RancoColors
                                .textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                  loading: () => const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(12),
                      child:
                          CircularProgressIndicator(),
                    ),
                  ),
                  error: (
                    error,
                    stackTrace,
                  ) =>
                      Text(
                    failureMessage(
                      error,
                      'No pudimos cargar los servicios.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _NextButton(
                text: 'Guardar y continuar',
                loading: _saving,
                onPressed: _next,
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            Text(
          failureMessage(
            error,
            'No pudimos cargar las categorías.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 4
  // ---------------------------------------------------------------------------

  Widget _coverageStep() {
    final locations =
        ref.watch(locationsProvider);

    return _RegistrationPage(
      title: 'Ubicación y cobertura',
      subtitle:
          'Selecciona dónde se ubica o en qué localidades atiende tu negocio.',
      child: locations.when(
        data: (items) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const _SectionHint(
                icon:
                    Icons.location_on_outlined,
                title: 'Localidades',
                message:
                    'Puedes seleccionar una o varias según dónde atiendas.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map(
                  (location) {
                    final selected =
                        _coverageLocationIds
                            .contains(
                      location.id,
                    );

                    return FilterChip(
                      selected: selected,
                      showCheckmark: true,
                      avatar: selected
                          ? null
                          : const Icon(
                              Icons
                                  .location_on_outlined,
                              size: 16,
                            ),
                      label: Text(
                        location.name,
                      ),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _coverageLocationIds
                                .add(
                              location.id,
                            );
                          } else {
                            _coverageLocationIds
                                .remove(
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
              const SizedBox(height: 22),
              _NextButton(
                text: 'Guardar y revisar',
                loading: _saving,
                onPressed: _next,
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            Text(
          locationFailureMessage(
            error,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 5
  // ---------------------------------------------------------------------------

  Widget _reviewStep() {
    final draft =
        _currentDraftSnapshot();

    final categories =
        ref.watch(categoriesProvider).valueOrNull ??
            const [];

    final locations =
        ref.watch(locationsProvider).valueOrNull ??
            const [];

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
          (location) =>
              _coverageLocationIds
                  .contains(
            location.id,
          ),
        )
        .map(
          (location) => location.name,
        )
        .toList();

    final selectedServices =
        subcategories
            .where(
              (service) =>
                  _subcategoryIds.contains(
                service.id,
              ),
            )
            .toList();

    final serviceNames = selectedServices
        .where(
          (service) =>
              service.slug.toLowerCase() !=
              'general',
        )
        .map(
          (service) => service.name,
        )
        .toList();

    final hasGeneralService =
        selectedServices.any(
      (service) =>
          service.slug.toLowerCase() ==
          'general',
    );

    final requirements = draft == null
        ? const <OnboardingRequirement>[]
        : const BusinessOnboardingRequirements()
            .evaluate(
            draft,
          );

    final canSubmit = draft != null &&
        _termsAccepted &&
        requirements.every(
          (item) => item.satisfied,
        );

    String servicesSummary =
        'Pendiente';

    if (_businessType !=
        BusinessType.service) {
      servicesSummary = 'No aplica';
    } else if (serviceNames.isNotEmpty) {
      servicesSummary =
          serviceNames.join(', ');
    } else if (hasGeneralService) {
      servicesSummary =
          'Actividad general';
    }

    return _RegistrationPage(
      title: 'Revisa tu publicación',
      subtitle:
          'Confirma que la información esté completa antes de enviarla a revisión.',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(
            rows: [
              _SummaryRow(
                'Tipo',
                _businessType.label,
              ),
              _SummaryRow(
                'Nombre',
                _nameController.text.trim(),
              ),
              _SummaryRow(
                'Categoría',
                categoryName ?? 'Pendiente',
              ),
              if (_businessType ==
                  BusinessType.service)
                _SummaryRow(
                  'Servicios',
                  servicesSummary,
                ),
              _SummaryRow(
                'Localidades',
                locationNames.isEmpty
                    ? 'Pendiente'
                    : locationNames.join(
                        ', ',
                      ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label(
            'Requisitos',
          ),
          const SizedBox(height: 9),
          ...requirements.map(
            (requirement) =>
                _RequirementRow(
              satisfied:
                  requirement.satisfied,
              text:
                  requirement.message,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color:
                const Color(0xFFF7FAF8),
            borderRadius:
                BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                setState(() {
                  _termsAccepted =
                      !_termsAccepted;
                });
              },
              borderRadius:
                  BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  10,
                  10,
                  12,
                  10,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: _termsAccepted
                        ? RancoColors.forest
                        : const Color(
                            0xFFD3E1DA,
                          ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _termsAccepted,
                      onChanged: (value) {
                        setState(() {
                          _termsAccepted =
                              value ?? false;
                        });
                      },
                      visualDensity:
                          VisualDensity.compact,
                    ),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Confirmo que la información es correcta',
                            style: TextStyle(
                              color: RancoColors
                                  .textPrimary,
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Quiero enviar este negocio a revisión para su publicación inicial.',
                            style: TextStyle(
                              color: RancoColors
                                  .textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed:
                  canSubmit && !_saving
                      ? _submit
                      : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_outlined,
                      size: 18,
                    ),
              label: const Text(
                'Enviar a revisión',
              ),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    RancoColors.forest,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    const Color(
                  0xFFD9E7E0,
                ),
                disabledForegroundColor:
                    const Color(
                  0xFF728078,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
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

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        if (_categoryId !=
            service.categoryId) {
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
    final selected =
        _subcategoryIds.contains(
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
    if (_businessId != null &&
        type != _businessType) {
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
    final result = await ref
        .read(
          businessOnboardingRepositoryProvider,
        )
        .getLatestEditableDraft();

    if (!mounted) {
      return;
    }

    result.when(
      success: (draft) {
        if (draft != null) {
          _applyDraft(
            draft,
          );
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

    _businessType =
        draft.businessType;

    _nameController.text =
        draft.name;

    _descriptionController.text =
        draft.description ?? '';

    _phoneController.text =
        draft.phone ?? '';

    _whatsappController.text =
        draft.whatsapp ?? '';

    _emailController.text =
        draft.email ?? '';

    _websiteController.text =
        draft.website ?? '';

    _addressController.text =
        draft.addressText ?? '';

    _categoryId =
        draft.primaryCategoryId;

    _coverageLocationIds
      ..clear()
      ..addAll(
        draft.coverage.map(
          (location) =>
              location.id,
        ),
      );

    _subcategoryIds
      ..clear()
      ..addAll(
        draft.services.map(
          (service) =>
              service.subcategory.id,
        ),
      );

    _termsAccepted =
        draft.onboardingMetadata[
                'terms_accepted'] ==
            true;

    _step = (draft
                .onboardingMetadata[
                    'last_section']
            as num?)
        ?.toInt() ??
        0;

    _step = _step.clamp(
      0,
      _steps.length - 1,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(
            _step,
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SNAPSHOT LOCAL
  // ---------------------------------------------------------------------------

  BusinessDraft?
      _currentDraftSnapshot() {
    final id = _businessId;

    if (id == null) {
      return null;
    }

    return BusinessDraft(
      id: id,
      businessType: _businessType,
      publicationStatus:
          BusinessPublicationStatus.draft,
      name: _nameController.text,
      description:
          _descriptionController.text,
      phone: _phoneController.text,
      whatsapp:
          _whatsappController.text,
      email: _emailController.text,
      website:
          _websiteController.text,
      primaryCategoryId:
          _categoryId,
      addressText:
          _addressController.text,
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
            (id) =>
                BusinessDraftService(
              subcategory:
                  Subcategory(
                id: id,
                categoryId:
                    _categoryId ?? '',
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
        'terms_accepted':
            _termsAccepted,
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

    final name =
        _nameController.text
                .trim()
                .isEmpty
            ? 'Nuevo negocio'
            : _nameController.text
                .trim();

    final result = await ref
        .read(
          businessOnboardingRepositoryProvider,
        )
        .createBusinessDraft(
          businessType:
              _businessType,
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
    if (_businessType ==
            BusinessType.service &&
        _step >= 2 &&
        _categoryId != null &&
        _subcategoryIds.isEmpty) {
      setState(() {
        _error =
            'Selecciona al menos un servicio para continuar.';
      });

      return false;
    }

    setState(() {
      _saving = true;

      _error = null;
      _statusMessage = null;
    });

    final hasDraft =
        await _ensureDraft();

    if (!hasDraft) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      return false;
    }

    final input =
        BusinessDraftInput(
      businessId: _businessId!,
      name: _nameController.text
          .trim(),
      description:
          _descriptionController.text
              .trim(),
      phone: _phoneController.text
          .trim(),
      whatsapp:
          _whatsappController.text
              .trim(),
      email: _emailController.text
          .trim(),
      website:
          _websiteController.text
              .trim(),
      primaryCategoryId:
          _categoryId,
      addressText:
          _addressController.text
              .trim(),
      coverageLocationIds:
          _coverageLocationIds
              .toList(),
      serviceItems:
          _businessType ==
                  BusinessType.service
              ? _subcategoryIds
                  .map(
                    (id) =>
                        ServiceDraftInput(
                      subcategoryId:
                          id,
                    ),
                  )
                  .toList()
              : const [],
      onboardingMetadata: {
        'last_section':
            nextStep ?? _step,
        'terms_accepted':
            _termsAccepted,
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

          _statusMessage =
              'Borrador guardado.';
        });

        return true;
      },
      failure: (failure) {
        setState(() {
          _saving = false;

          _error =
              failure.message;
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
    if (_step >=
        _steps.length - 1) {
      return;
    }

    if (_step == 1) {
      if (_nameController.text
              .trim()
              .length <
          3) {
        setState(() {
          _error =
              'Agrega un nombre comercial válido para continuar.';
        });

        return;
      }
    }

    if (_step == 2) {
      if (_categoryId == null) {
        setState(() {
          _error =
              'Selecciona una categoría para continuar.';
        });

        return;
      }

      if (_businessType ==
              BusinessType.service &&
          _subcategoryIds.isEmpty) {
        setState(() {
          _error =
              'Selecciona al menos un servicio para continuar.';
        });

        return;
      }
    }

    if (_step == 3 &&
        _coverageLocationIds.isEmpty) {
      setState(() {
        _error =
            'Selecciona al menos una localidad para continuar.';
      });

      return;
    }

    final target =
        _step + 1;

    final saved =
        await _saveDraft(
      nextStep: target,
    );

    if (!saved || !mounted) {
      return;
    }

    setState(() {
      _step = target;
    });

    await _pageController
        .animateToPage(
      _step,
      duration: const Duration(
        milliseconds: 250,
      ),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------------------
  // VOLVER
  // ---------------------------------------------------------------------------

  void _back() {
    if (_step == 0) {
      context.go(
        '/provider/join',
      );

      return;
    }

    setState(() {
      _step--;
      _error = null;
      _statusMessage = null;
    });

    _pageController.animateToPage(
      _step,
      duration: const Duration(
        milliseconds: 250,
      ),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------------------
  // ENVIAR REVISIÓN
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_termsAccepted) {
      setState(() {
        _error =
            'Confirma que la información es correcta antes de enviarla.';
      });

      return;
    }

    final draft =
        _currentDraftSnapshot();

    if (draft == null) {
      return;
    }

    final requirements =
        const BusinessOnboardingRequirements()
            .evaluate(
      draft,
    );

    final missing =
        requirements
            .where(
              (item) =>
                  !item.satisfied,
            )
            .toList();

    if (missing.isNotEmpty) {
      setState(() {
        _error =
            'Completa los requisitos pendientes antes de enviar el negocio.';
      });

      return;
    }

    final saved =
        await _saveDraft(
      nextStep: _step,
    );

    if (!saved ||
        _businessId == null) {
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
        ref.invalidate(
          myProviderBusinessesProvider,
        );

        context.go(
          '/provider/status',
        );
      },
      failure: (failure) {
        setState(() {
          _saving = false;

          _error =
              failure.message;
        });
      },
    );
  }
}

// =============================================================================
// PROGRESO
// =============================================================================

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.steps,
  });

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        6,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(
              steps.length,
              (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin:
                        EdgeInsets.only(
                      right: index ==
                              steps.length -
                                  1
                          ? 0
                          : 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: index <= step
                          ? RancoColors
                              .forest
                          : const Color(
                              0xFFD5E3DD,
                            ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Paso ${step + 1} de ${steps.length} · ${steps[step]}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: const Color(
                    0xFF6B7D75,
                  ),
                  fontWeight:
                      FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CONTENIDO DE CADA PASO
// =============================================================================

class _RegistrationPage
    extends StatelessWidget {
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
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior
              .onDrag,
      padding:
          const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 620,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color:
                          RancoColors.forest,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          -0.35,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: const Color(
                        0xFF6B7D75,
                      ),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LABEL
// =============================================================================

class _Label extends StatelessWidget {
  const _Label(
    this.text,
  );

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(
            color:
                const Color(
              0xFF50665D,
            ),
            fontWeight:
                FontWeight.w800,
            letterSpacing: .85,
          ),
    );
  }
}

// =============================================================================
// BOTÓN SIGUIENTE
// =============================================================================

class _NextButton
    extends StatelessWidget {
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
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed:
            loading ? null : onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 17,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons
                    .arrow_forward_rounded,
                size: 18,
              ),
        label: Text(
          text,
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              RancoColors.forest,
          foregroundColor:
              Colors.white,
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
            fontSize: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TIPO DE NEGOCIO
// =============================================================================

class _TypeCard
    extends StatelessWidget {
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
      color: selected
          ? const Color(
              0xFFF0F8F4,
            )
          : Colors.white,
      borderRadius:
          BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            11,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              15,
            ),
            border: Border.all(
              color: selected
                  ? RancoColors
                      .forest
                  : const Color(
                      0xFFD5E2DC,
                    ),
              width:
                  selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .center,
            children: [
              Container(
                width: 35,
                height: 35,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color: selected
                      ? const Color(
                          0xFFDDEFE7,
                        )
                      : const Color(
                          0xFFF1F6F3,
                        ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      RancoColors.forest,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .w800,
                        color: Color(
                          0xFF31443B,
                        ),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: Color(
                          0xFF708179,
                        ),
                      ),
                    ),
                  ],
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
// RESUMEN
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  const _SummaryCard({
    required this.rows,
  });

  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: const Color(
            0xFFD7E4DE,
          ),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0;
              index < rows.length;
              index++) ...[
            _SummaryLine(
              row: rows[index],
            ),
            if (index !=
                rows.length - 1)
              const Divider(
                height: 15,
                color: Color(
                  0xFFE7EEEA,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine
    extends StatelessWidget {
  const _SummaryLine({
    required this.row,
  });

  final _SummaryRow row;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final narrow =
            constraints.maxWidth <
                330;

        if (narrow) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                row.label,
                style:
                    const TextStyle(
                  color: Color(
                    0xFF708179,
                  ),
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                row.value.isEmpty
                    ? 'Pendiente'
                    : row.value,
                maxLines: 3,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  color: RancoColors
                      .textPrimary,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                row.label,
                style:
                    const TextStyle(
                  color: Color(
                    0xFF708179,
                  ),
                  fontSize: 11.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                row.value.isEmpty
                    ? 'Pendiente'
                    : row.value,
                maxLines: 3,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  color: RancoColors
                      .textPrimary,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryRow {
  const _SummaryRow(
    this.label,
    this.value,
  );

  final String label;
  final String value;
}

// =============================================================================
// AYUDA DE SECCIÓN
// =============================================================================

class _SectionHint
    extends StatelessWidget {
  const _SectionHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment:
              Alignment.center,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE7F2ED,
            ),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color:
                RancoColors.forest,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  color: RancoColors
                      .textPrimary,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                message,
                style:
                    const TextStyle(
                  color: RancoColors
                      .textSecondary,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TARJETA INFO
// =============================================================================

class _InfoCard
    extends StatelessWidget {
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
    final tone = warning
        ? const Color(
            0xFF9A6421,
          )
        : RancoColors.forest;

    final background = warning
        ? const Color(
            0xFFFFF7E9,
          )
        : const Color(
            0xFFF1F8F5,
          );

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color: tone.withValues(
            alpha: .24,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: tone,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  message,
                  style:
                      const TextStyle(
                    color: RancoColors
                        .textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
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

class _RequirementRow
    extends StatelessWidget {
  const _RequirementRow({
    required this.satisfied,
    required this.text,
  });

  final bool satisfied;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = satisfied
        ? RancoColors.forest
        : const Color(
            0xFFB4543F,
          );

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            satisfied
                ? Icons
                    .check_circle_outline_rounded
                : Icons
                    .error_outline_rounded,
            color: tone,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                color: RancoColors
                    .textPrimary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MENSAJE
// =============================================================================

class _InlineMessage
    extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    this.error = false,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        7,
        18,
        0,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: error
              ? const Color(
                  0xFFFFE8E5,
                )
              : const Color(
                  0xFFE1F0EA,
                ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              error
                  ? Icons
                      .error_outline_rounded
                  : Icons
                      .check_circle_outline_rounded,
              size: 17,
              color: error
                  ? const Color(
                      0xFF8C2F28,
                    )
                  : RancoColors
                      .forest,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error
                      ? const Color(
                          0xFF8C2F28,
                        )
                      : RancoColors
                          .forest,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}