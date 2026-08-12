class AdCampaign {
  final String id;
  final String title;
  final String splashImageUrl;
  final String splashActionUrl;
  final String bottomBannerImageUrl;
  final String bottomBannerActionUrl;
  final bool isActive;
  final int splashDurationSeconds;

  AdCampaign({
    required this.id,
    required this.title,
    required this.splashImageUrl,
    required this.splashActionUrl,
    required this.bottomBannerImageUrl,
    required this.bottomBannerActionUrl,
    this.isActive = true,
    this.splashDurationSeconds = 5,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Campaña Publicitaria',
      splashImageUrl: json['splashImageUrl'] ?? '',
      splashActionUrl: json['splashActionUrl'] ?? '',
      bottomBannerImageUrl: json['bottomBannerImageUrl'] ?? '',
      bottomBannerActionUrl: json['bottomBannerActionUrl'] ?? '',
      isActive: json['isActive'] ?? true,
      splashDurationSeconds: json['splashDurationSeconds'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'splashImageUrl': splashImageUrl,
        'splashActionUrl': splashActionUrl,
        'bottomBannerImageUrl': bottomBannerImageUrl,
        'bottomBannerActionUrl': bottomBannerActionUrl,
        'isActive': isActive,
        'splashDurationSeconds': splashDurationSeconds,
      };
}
