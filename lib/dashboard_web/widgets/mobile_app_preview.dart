import 'package:flutter/material.dart';

class MobileAppPreview extends StatelessWidget {
  const MobileAppPreview({
    super.key,
    required this.brandName,
    required this.logoUrl,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    this.isStreaming = false,
  });

  final String brandName;
  final String logoUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final bool isStreaming;

  Color _parseColor(String hexStr, Color fallback) {
    if (hexStr.isEmpty) return fallback;
    String cleanHex = hexStr.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    if (cleanHex.length == 8) {
      return Color(int.tryParse(cleanHex, radix: 16) ?? fallback.toARGB32());
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = _parseColor(primaryColorHex, scheme.primary);
    final secondaryColor = _parseColor(secondaryColorHex, primaryColor);

    return Container(
      width: 280,
      height: 580,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest, // Inner background of phone
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: scheme.outlineVariant, width: 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.surfaceContainerLowest,
                      secondaryColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48), // Top padding / notch area
                
                // Top App Bar Simulator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.menu, color: scheme.onSurface),
                      Icon(Icons.notifications_outlined, color: scheme.onSurface),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Logo area
                Center(
                  child: isStreaming
                      ? Container(
                          width: 240,
                          height: 135, // 16:9 ratio approx
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: logoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderLogo(primaryColor),
                                  ),
                                )
                              : _buildPlaceholderLogo(primaryColor),
                        )
                      : Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: logoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Image.network(
                                      logoUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderLogo(primaryColor),
                                    ),
                                  ),
                                )
                              : _buildPlaceholderLogo(primaryColor),
                        ),
                ),
                
                const SizedBox(height: 24),
                
                // Station name
                Text(
                  brandName.isNotEmpty ? brandName : 'Mi Estación',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                
                const Spacer(),
                
                // Player Controls Simulator
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Progress bar
                      if (!isStreaming)
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 80,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(isStreaming ? Icons.cast : Icons.skip_previous, color: scheme.onSurfaceVariant),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          Icon(isStreaming ? Icons.fullscreen : Icons.skip_next, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderLogo(Color color) {
    return Icon(
      isStreaming ? Icons.tv : Icons.radio,
      size: 48,
      color: color,
    );
  }
}
