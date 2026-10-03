import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consent_repository.dart';
import 'consent_fields.dart';

Future<bool> requireActionConsent(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  var terms = false;
  var privacy = false;
  var dataProcessing = false;
  var saving = false;
  String? error;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Antes de continuar'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Confirma cómo usaremos tus datos para gestionar esta solicitud.'),
              ConsentFields(
                terms: terms,
                privacy: privacy,
                dataProcessing: dataProcessing,
                onTerms: (value) => setState(() => terms = value),
                onPrivacy: (value) => setState(() => privacy = value),
                onDataProcessing: (value) =>
                    setState(() => dataProcessing = value),
              ),
              if (error != null)
                Text(error!,
                    style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                saving ? null : () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: saving || !terms || !privacy || !dataProcessing
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(consentRepositoryProvider)
                          .record(context: action);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        setState(() {
                          error =
                              'No pudimos guardar tu consentimiento. Intenta nuevamente.';
                          saving = false;
                        });
                      }
                    }
                  },
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );
  return accepted == true;
}
