import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/models/marca_summary.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';

/// Header de identidad de marca en el sidebar — estilo "perfil de cuenta".
class BrandIdentityHeader extends StatelessWidget {
  const BrandIdentityHeader({
    super.key,
    required this.dataStore,
    required this.userEmail,
    this.compact = false,
  });

  final ClientDataStore dataStore;
  final String userEmail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataStore,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final initializing = dataStore.initializing && dataStore.data == null;
        final info = dataStore.data?.info;
        final logoUrl = info?.logoUrl ?? '';
        final hasLogo = logoUrl.trim().startsWith('http');

        String title;
        if (initializing) {
          title = 'Cargando…';
        } else {
          final fromInfo = info?.nombreGrupo.trim() ?? '';
          if (fromInfo.isNotEmpty) {
            title = fromInfo;
          } else {
            MarcaSummary? marca;
            for (final m in dataStore.marcas) {
              if (m.id == dataStore.currentAppId) {
                marca = m;
                break;
              }
            }
            final fromMarca = marca?.nombreGrupo.trim() ?? '';
            title = fromMarca.isNotEmpty ? fromMarca : 'Radio Panel';
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 16 : 20, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo circular
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? Image.network(
                        logoUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, _) => Icon(
                          Icons.storefront_outlined,
                          size: 26,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.storefront_outlined,
                        size: 26,
                        color: scheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              // Nombre y email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

