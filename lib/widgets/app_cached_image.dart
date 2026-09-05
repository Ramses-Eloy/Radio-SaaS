import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppCachedImage extends StatefulWidget {
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
  State<AppCachedImage> createState() => _AppCachedImageState();
}

class _AppCachedImageState extends State<AppCachedImage> {
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void didUpdateWidget(covariant AppCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryCount = 0;
    }
  }

  void _handleError() {
    if (_retryCount < _maxRetries) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _retryCount++;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _buildFallback();
    }

    return CachedNetworkImage(
      key: ValueKey('${cleanUrl}_$_retryCount'),
      imageUrl: cleanUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: widget.fadeInDuration,
      placeholder: (context, url) =>
          widget.placeholder ??
          Center(
            child: SizedBox(
              width: (widget.width != null && widget.width! < 30) ? widget.width! * 0.5 : 18.0,
              height: (widget.height != null && widget.height! < 30) ? widget.height! * 0.5 : 18.0,
              child: const CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
      errorWidget: (context, url, error) {
        if (_retryCount < _maxRetries) {
          _handleError();
          return widget.placeholder ??
              Center(
                child: SizedBox(
                  width: (widget.width != null && widget.width! < 30) ? widget.width! * 0.5 : 18.0,
                  height: (widget.height != null && widget.height! < 30) ? widget.height! * 0.5 : 18.0,
                  child: const CircularProgressIndicator(strokeWidth: 2.0),
                ),
              );
        }
        return widget.errorWidget ?? _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white10,
      child: Center(
        child: Icon(
          Icons.radio,
          size: widget.fallbackIconSize,
          color: widget.fallbackIconColor ?? Colors.white70,
        ),
      ),
    );
  }
}

