import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../core/utils/chilean_phone.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../shared/models/location.dart';
import '../../../shared/models/service_request.dart';
import '../../businesses/application/business_providers.dart';
import '../../legal/application/legal_navigation.dart';
import '../application/service_request_providers.dart';
import '../data/service_request_repository.dart';

final _visitorRequestDraftProvider =
    StateProvider.family<_VisitorRequestDraft?, String>((ref, key) => null);

class _VisitorRequestDraft {
  const _VisitorRequestDraft({
    required this.serviceId,
    required this.message,
    required this.locationId,
    required this.address,
    required this.urgency,
    required this.desiredDate,
  });

  final String? serviceId;
  final String message;
  final String? locationId;
  final String address;
  final RequestUrgency urgency;
  final DateTime? desiredDate;
}

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedSubcategoryId;
  String? _selectedLocationId;
  RequestUrgency _urgency = RequestUrgency.normal;
  DateTime? _desiredDate;
  bool _saving = false;
  bool _consent = false;
  String? _error;

  String get _draftKey => 'visitor:${widget.businessId}';

  @override
  void initState() {
    super.initState();
    final draft = ref.read(_visitorRequestDraftProvider(_draftKey));
    if (draft == null) return;
    _selectedSubcategoryId = draft.serviceId;
    _descriptionController.text = draft.message;
    _selectedLocationId = draft.locationId;
    _addressController.text = draft.address;
    _urgency = draft.urgency;
    _desiredDate = draft.desiredDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(ref.read(_visitorRequestDraftProvider(_draftKey)), draft)) {
        ref.read(_visitorRequestDraftProvider(_draftKey).notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessDetailProvider(widget.businessId));
    final locations = ref.watch(locationsProvider);
    return Scaffold(
      appBar: const RancoAppBar(title: 'Solicitar servicio'),
      body: business.when(
        data: (business) {
          final services = business.services;
          final activeLocations = locations.valueOrNull;
          final availableLocations = activeLocations == null
              ? business.coverage
              : activeLocations
                  .where(
                    (location) => business.coverage.any(
                      (covered) => covered.id == location.id,
                    ),
                  )
                  .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RequestHeader(
                        businessName: business.name,
                        serviceCount: services.length,
                      ),
                      const SizedBox(height: 20),
                      if (services.isEmpty) ...[
                        const _UnavailablePanel(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.go('/business/${business.id}'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Volver al perfil'),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          initialValue: services.any((service) =>
                                  service.subcategory.id ==
                                  _selectedSubcategoryId)
                              ? _selectedSubcategoryId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Servicio',
                            prefixIcon:
                                Icon(Icons.home_repair_service_outlined),
                          ),
                          items: [
                            for (final service in services)
                              DropdownMenuItem(
                                value: service.subcategory.id,
                                child: Text(service.subcategory.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedSubcategoryId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona un servicio.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              const InputDecoration(labelText: 'Tu nombre'),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                                  ? 'Ingresa tu nombre.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Teléfono de contacto'),
                          validator: (value) =>
                              value == null || !isValidChileanPhone(value)
                                  ? 'Ingresa un teléfono válido.'
                                  : null,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _consent,
                          onChanged: (value) =>
                              setState(() => _consent = value ?? false),
                          title: const Text(
                              'Acepto que mis datos se compartan con el proveedor para gestionar esta solicitud.'),
                          subtitle: TextButton(
                            onPressed: () =>
                                openLegalPage(context, '/politica-privacidad'),
                            child: const Text('Leer política de privacidad'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 4,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Describe lo que necesitas',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) =>
                              (value == null || value.trim().length < 12)
                                  ? 'Cuéntanos un poco más.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: availableLocations.any((location) =>
                                  location.id == _selectedLocationId)
                              ? _selectedLocationId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Localidad',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          items: [
                            for (final location in availableLocations)
                              DropdownMenuItem(
                                value: location.id,
                                child: Text(_locationLabel(location)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedLocationId = value),
                          validator: (value) => value == null
                              ? 'Selecciona una localidad.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Dirección o referencia opcional',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RequestUrgency>(
                          initialValue: _urgency,
                          decoration: const InputDecoration(
                            labelText: 'Urgencia',
                            prefixIcon: Icon(Icons.priority_high_rounded),
                          ),
                          items: [
                            for (final urgency in RequestUrgency.values)
                              DropdownMenuItem(
                                  value: urgency, child: Text(urgency.label)),
                          ],
                          onChanged: (value) => setState(
                              () => _urgency = value ?? RequestUrgency.normal),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _desiredDate == null
                                ? 'Elegir fecha deseada'
                                : '${_desiredDate!.day}/${_desiredDate!.month}/${_desiredDate!.year}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed:
                              _saving ? null : () => _submit(business.id),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: const Text('Enviar solicitud'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const RancoLoadingState(),
        error: (error, stackTrace) => RancoErrorState(
          message: 'No pudimos cargar los servicios de este negocio.',
          onRetry: () =>
              ref.invalidate(businessDetailProvider(widget.businessId)),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _desiredDate ?? now,
    );
    if (picked != null) {
      setState(() => _desiredDate = picked);
    }
  }

  Future<void> _submit(String businessId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final business =
        ref.read(businessDetailProvider(widget.businessId)).valueOrNull;
    final service = business?.services.firstWhere(
      (item) => item.subcategory.id == _selectedSubcategoryId,
    );
    if (business == null || service == null) {
      return;
    }
    if (!_consent) {
      setState(() =>
          _error = 'Debes aceptar el aviso de privacidad para continuar.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result =
        await ref.read(serviceRequestRepositoryProvider).createDirectRequest(
              CreateServiceRequestInput(
                businessId: businessId,
                categoryId: service.subcategory.categoryId,
                subcategoryId: service.subcategory.id,
                locationId: _selectedLocationId,
                description: _descriptionController.text,
                addressText: _addressController.text,
                urgency: _urgency,
                desiredDate: _desiredDate,
                customerName: _nameController.text,
                customerPhone: _phoneController.text,
                consentVersion: 'privacy-2026-10-01',
              ),
            );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        ref.invalidate(myRequestsProvider);
        ref.invalidate(myCustomerActivityProvider);
        ref.invalidate(providerRequestQueueProvider);
        await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: const Text('Solicitud enviada'),
                  content: const Text(
                      'El proveedor podrá contactarte al número indicado.'),
                  actions: [
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Listo'))
                  ],
                ));
        if (mounted) context.go('/business/$businessId');
      case Failure(:final error):
        setState(() => _error = error.message);
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

String _locationLabel(Location location) {
  final commune = location.communeName;

  if (commune == null || commune.isEmpty) {
    return location.name;
  }

  return '${location.name} · $commune';
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.businessName,
    required this.serviceCount,
  });

  final String businessName;
  final int serviceCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  serviceCount == 1
                      ? '1 servicio disponible para solicitar'
                      : '$serviceCount servicios disponibles para solicitar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Este prestador todavía no tiene servicios publicados para recibir solicitudes directas.',
            ),
          ),
        ],
      ),
    );
  }
}
