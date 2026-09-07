import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../shared/models/service_request.dart';
import '../../businesses/application/business_providers.dart';
import '../application/service_request_providers.dart';
import '../data/service_request_repository.dart';

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
  String? _selectedSubcategoryId;
  RequestUrgency _urgency = RequestUrgency.normal;
  DateTime? _desiredDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessDetailProvider(widget.businessId));
    return Scaffold(
      appBar: const RancoAppBar(title: 'Solicitar servicio'),
      body: business.when(
        data: (business) {
          final services = business.services;
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
                      Text(business.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSubcategoryId,
                        decoration:
                            const InputDecoration(labelText: 'Servicio'),
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
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                            labelText: 'Describe lo que necesitas'),
                        validator: (value) =>
                            (value == null || value.trim().length < 12)
                                ? 'Cuéntanos un poco más.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                            labelText: 'Dirección o referencia'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Ingresa una dirección o referencia.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<RequestUrgency>(
                        initialValue: _urgency,
                        decoration:
                            const InputDecoration(labelText: 'Urgencia'),
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
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving || services.isEmpty
                            ? null
                            : () => _submit(business.id),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Enviar solicitud'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(requestFailureMessage(error))),
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
                description: _descriptionController.text,
                addressText: _addressController.text,
                urgency: _urgency,
                desiredDate: _desiredDate,
              ),
            );
    if (!mounted) {
      return;
    }
    result.when(
      success: (request) {
        ref.invalidate(myRequestsProvider);
        context.go('/requests/${request.id}');
      },
      failure: (failure) => setState(() => _error = failure.message),
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}
