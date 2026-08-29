import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? fallbackIconColor;
  final double fallbackIconSize;
  final Duration fadeInDuration;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fallbackIconColor,
    this.fallbackIconSize = 24.0,
    this.fadeInDuration = const Duration(milliseconds: 250),
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _buildFallback();
    }

    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) =>
          placeholder ??
          Center(
            child: SizedBox(
              width: (width != null && width! < 30) ? width! * 0.5 : 18.0,
              height: (height != null && height! < 30) ? height! * 0.5 : 18.0,
              child: const CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
      errorWidget: (context, url, error) => errorWidget ?? _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: Colors.white10,
      child: Center(
        child: Icon(
          Icons.radio,
          size: fallbackIconSize,
          color: fallbackIconColor ?? Colors.white70,
        ),
      ),
    );
  }
}
