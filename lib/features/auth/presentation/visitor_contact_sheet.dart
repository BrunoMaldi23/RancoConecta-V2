import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../legal/data/consent_repository.dart';
import '../../legal/presentation/action_consent_dialog.dart';
import '../../legal/presentation/consent_fields.dart';
import '../../profile/application/profile_providers.dart';
import '../application/auth_controller.dart';
import '../data/supabase_auth_repository.dart';
import '../data/visitor_profile_repository.dart';
import 'visitor_contact_validation.dart';

Future<bool> ensureVisitorContactAndConsent(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final user = ref.read(authRepositoryProvider).currentUser() ??
      ref.read(authStateProvider).valueOrNull;
  if (user != null && user.isAnonymous) {
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if ((profile.fullName?.trim().length ?? 0) >= 3 &&
          isValidChileanWhatsapp(profile.phone)) {
        if (!context.mounted) return false;
        return requireActionConsent(context, ref, action: action);
      }
    } catch (_) {
      // The form can still collect the contact details for this session.
    }
  } else if (user != null) {
    return requireActionConsent(context, ref, action: action);
  }
  if (!context.mounted) return false;
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _VisitorContactSheet(action: action),
      ) ==
      true;
}

class _VisitorContactSheet extends ConsumerStatefulWidget {
  const _VisitorContactSheet({required this.action});

  final String action;

  @override
  ConsumerState<_VisitorContactSheet> createState() =>
      _VisitorContactSheetState();
}

class _VisitorContactSheetState extends ConsumerState<_VisitorContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _locationId;
  bool _terms = false;
  bool _privacy = false;
  bool _processing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() ||
        !_terms ||
        !_privacy ||
        !_processing) {
      setState(() =>
          _error = 'Completa los datos y acepta los tres consentimientos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (ref.read(authRepositoryProvider).currentUser() == null) {
        final session =
            await ref.read(authRepositoryProvider).signInAnonymously();
        if (session case Failure(:final error)) throw StateError(error.message);
      }
      final saved = await ref.read(visitorProfileRepositoryProvider).save(
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text.trim().isEmpty ? null : _email.text,
            locationId: _locationId,
          );
      if (saved case Failure(:final error)) throw StateError(error.message);
      await ref.read(consentRepositoryProvider).record(context: widget.action);
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar tus datos. Intenta nuevamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider).valueOrNull ?? [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tus datos de contacto',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text(
                      'El negocio los usará para responder a esta solicitud.'),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Nombre completo *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Ingresa tu nombre completo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: 'WhatsApp *', hintText: '+56 9 XXXX XXXX'),
                    keyboardType: TextInputType.phone,
                    validator: validateVisitorWhatsapp,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico (opcional)'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null &&
                            value.trim().isNotEmpty &&
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())
                        ? 'Ingresa un correo válido.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _locationId,
                    decoration: const InputDecoration(
                        labelText: 'Localidad (opcional)'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Sin seleccionar')),
                      for (final location in locations)
                        DropdownMenuItem(
                            value: location.id, child: Text(location.name)),
                    ],
                    onChanged: (value) =>
                        _locationId = value == '' ? null : value,
                  ),
                  const SizedBox(height: 12),
                  ConsentFields(
                    terms: _terms,
                    privacy: _privacy,
                    dataProcessing: _processing,
                    onTerms: (value) => setState(() => _terms = value),
                    onPrivacy: (value) => setState(() => _privacy = value),
                    onDataProcessing: (value) =>
                        setState(() => _processing = value),
                  ),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _continue,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continuar con la solicitud'),
                    ),
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
