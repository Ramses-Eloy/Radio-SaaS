import 'package:flutter/material.dart';
import '../models/ad_campaign.dart';
import '../services/telemetry_service.dart';

class AdProvider extends ChangeNotifier {
  bool _showSplashAd = true;
  bool get showSplashAd => _showSplashAd && _activeCampaign.isActive;

  AdCampaign _activeCampaign = AdCampaign(
    id: 'camp_001',
    title: 'Publicidad Especial Sira Radio',
    splashImageUrl: '',
    splashActionUrl: '',
    bottomBannerImageUrl: '',
    bottomBannerActionUrl: '',
    isActive: true,
    splashDurationSeconds: 5,
  );

  AdCampaign get activeCampaign => _activeCampaign;

  void syncMarcaAdConfig({
    required String splashUrl,
    required String bannerHomeUrl,
  }) {
    _activeCampaign = AdCampaign(
      id: _activeCampaign.id,
      title: _activeCampaign.title,
      splashImageUrl: splashUrl.isNotEmpty ? splashUrl : _activeCampaign.splashImageUrl,
      splashActionUrl: _activeCampaign.splashActionUrl,
      bottomBannerImageUrl: bannerHomeUrl.isNotEmpty ? bannerHomeUrl : _activeCampaign.bottomBannerImageUrl,
      bottomBannerActionUrl: _activeCampaign.bottomBannerActionUrl,
      isActive: _activeCampaign.isActive,
      splashDurationSeconds: _activeCampaign.splashDurationSeconds,
    );
    notifyListeners();
  }

  void dismissSplashAd() {
    _showSplashAd = false;
    notifyListeners();
  }

  void updateCampaignDetails({
    required String splashImageUrl,
    required String splashActionUrl,
    required String bottomBannerImageUrl,
    required String bottomBannerActionUrl,
    required bool isActive,
    required int splashDurationSeconds,
  }) {
    _activeCampaign = AdCampaign(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Campaña Publicitaria',
      splashImageUrl: splashImageUrl,
      splashActionUrl: splashActionUrl,
      bottomBannerImageUrl: bottomBannerImageUrl,
      bottomBannerActionUrl: bottomBannerActionUrl,
      isActive: isActive,
      splashDurationSeconds: splashDurationSeconds.clamp(1, 5),
    );
    notifyListeners();
  }

  void logAdClick({required String adType, required String stationId}) {
    final targetUrl = adType == 'splash'
        ? _activeCampaign.splashActionUrl
        : _activeCampaign.bottomBannerActionUrl;

    TelemetryService().logEvent(
      eventType: 'ad_click',
      stationId: stationId,
      targetUrl: targetUrl,
      metadata: {
        'adType': adType,
        'campaignId': _activeCampaign.id,
        'campaignTitle': _activeCampaign.title,
      },
    );
  }
}
