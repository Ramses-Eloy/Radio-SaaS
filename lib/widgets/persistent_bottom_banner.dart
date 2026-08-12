import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ad_provider.dart';
import '../providers/station_provider.dart';
import 'app_cached_image.dart';

class PersistentBottomBanner extends StatelessWidget {
  const PersistentBottomBanner({super.key});

  Future<void> _handleBannerClick(BuildContext context, String url, String stationId) async {
    context.read<AdProvider>().logAdClick(adType: 'banner', stationId: stationId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adProvider = context.watch<AdProvider>();
    final stationProvider = context.watch<StationProvider>();
    final campaign = adProvider.activeCampaign;
    final bannerUrl = stationProvider.brandBannerHomeUrl.isNotEmpty 
        ? stationProvider.brandBannerHomeUrl 
        : campaign.bottomBannerImageUrl;

    if (bannerUrl.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 75,
      color: Colors.black,
      child: GestureDetector(
        onTap: () => _handleBannerClick(
          context,
          campaign.bottomBannerActionUrl,
          stationProvider.currentStation.id,
        ),
        child: AppCachedImage(
          imageUrl: bannerUrl,
          width: double.infinity,
          height: 75,
          fit: BoxFit.cover,
          errorWidget: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
