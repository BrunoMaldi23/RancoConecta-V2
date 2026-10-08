import 'package:flutter/material.dart';
import '../application/legal_navigation.dart';

const termsVersion = '2026-10-01';
const privacyVersion = '2026-10-01';

const _ink = Color(0xFF183027);
const _muted = Color(0xFF64786F);
const _line = Color(0xFFE1EBE6);
const _accentDark = Color(0xFF145A3A);

/// Bloque de consentimientos: tres filas independientes (nunca marcadas por
/// defecto). Cada fila alinea casilla, texto y su enlace de lectura.
class ConsentFields extends StatelessWidget {
  const ConsentFields({
    required this.terms,
    required this.privacy,
    required this.dataProcessing,
    required this.onTerms,
    required this.onPrivacy,
    required this.onDataProcessing,
    super.key,
  });

  final bool terms;
  final bool privacy;
  final bool dataProcessing;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool> onDataProcessing;

  @override
  Widget build(BuildContext context) => Material(
        // Material propio: los CheckboxListTile pintan su feedback aquí.
        color: const Color(0xFFF8FBF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'Antes de continuar',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _ConsentRow(
              value: terms,
              onChanged: onTerms,
              label: 'Acepto los términos y condiciones',
              linkLabel: 'Ver términos',
              route: '/terminos',
            ),
            const _RowDivider(),
            _ConsentRow(
              value: privacy,
              onChanged: onPrivacy,
              label: 'Acepto la política de privacidad',
              linkLabel: 'Ver política de privacidad',
              route: '/politica-privacidad',
            ),
            const _RowDivider(),
            _ConsentRow(
              value: dataProcessing,
              onChanged: onDataProcessing,
              label: 'Autorizo el tratamiento de mis datos personales',
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 52,
        endIndent: 16,
        color: _line,
      );
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.linkLabel,
    this.route,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? linkLabel;
  final String? route;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.only(left: 6, right: 12),
        visualDensity: VisualDensity.compact,
        title: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            height: 1.35,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
          ),
        ),
        // El enlace consume su propio toque: abrir el documento nunca marca
        // la casilla.
        subtitle: linkLabel == null || route == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: _ConsentLink(label: linkLabel!, route: route!),
              ),
      );
}

class _ConsentLink extends StatelessWidget {
  const _ConsentLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => openLegalPage(context, route),
        style: TextButton.styleFrom(
          foregroundColor: _accentDark,
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.only(right: 4),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0x66145A3A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            const SizedBox(width: 2),
            const Icon(Icons.north_east_rounded, size: 13, color: _muted),
          ],
        ),
      );
}
