import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';

const _logoAsset = 'assets/branding/ranco_logo_login.png';

// Geometría del asset real (1536×1024): emblema circular centrado en
// (768, 381) con ~452 px de diámetro. No se genera un logo nuevo: se muestra
// solo esa zona del mismo archivo.
const _assetWidth = 1536.0;
const _assetHeight = 1024.0;
const _emblemCenterX = 768.0;
const _emblemCenterY = 381.0;
const _emblemDiameter = 452.0;

/// Emblema circular de Ranco Conecta tomado del logo oficial.
class RancoBrandMark extends StatelessWidget {
  const RancoBrandMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = size / _emblemDiameter;
    return Semantics(
      image: true,
      label: 'Ranco Conecta',
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: size / 2 - _emblemCenterX * scale,
                top: size / 2 - _emblemCenterY * scale,
                width: _assetWidth * scale,
                height: _assetHeight * scale,
                child: Image.asset(
                  _logoAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: RancoColors.primarySoft,
                    child: Icon(Icons.landscape_outlined,
                        color: RancoColors.forest),
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

/// Bloque de marca: emblema + "Ranco Conecta" con los colores del logotipo,
/// y una línea secundaria opcional (p. ej. "Administración").
class RancoBrandLockup extends StatelessWidget {
  const RancoBrandLockup({
    this.subtitle,
    this.markSize = 38,
    this.fontSize = 17,
    super.key,
  });

  final String? subtitle;
  final double markSize;
  final double fontSize;

  /// Naranja del logotipo ("Conecta").
  static const accent = Color(0xFFD9541E);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RancoBrandMark(size: markSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(
                        text: 'Ranco ',
                        style: TextStyle(color: RancoColors.pine),
                      ),
                      TextSpan(
                        text: 'Conecta',
                        style: TextStyle(color: accent),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.2,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
