import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo de Kosmos (icono "K" + nombre). Los PNG viven en `web/branding/`,
/// así no se empaquetan en las apps móviles.
class KosmosLogo extends StatelessWidget {
  const KosmosLogo({super.key, this.size = 40, this.showName = true, this.subtitle});

  final double size;
  final bool showName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final icon = Image.network(
      isDark ? 'branding/kosmos-icon-light.png' : 'branding/kosmos-icon.png',
      width: size,
      height: size,
      errorBuilder: (_, _, _) => Icon(Icons.podcasts, size: size * 0.8, color: scheme.primary),
    );
    if (!showName) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: size * 0.25),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KOSMOS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w800,
                letterSpacing: size * 0.06,
                color: isDark ? Colors.white : const Color(0xFF0B1A2E),
                height: 1,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
