import 'package:flutter/material.dart';

/// Vista previa de imagen remota con caché del navegador y decodificación reducida.
class CachedDashboardImage extends StatelessWidget {
  const CachedDashboardImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) {
      return const SizedBox.shrink();
    }

    Widget image = Image.network(
      trimmed,
      key: ValueKey<String>(trimmed),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.broken_image_outlined,
        size: (width ?? height ?? 40).clamp(24, 56),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
