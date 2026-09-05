class TvChannel {
  final String id;
  final String name;
  final String streamUrl;
  final String imageUrl;
  final String logoCarouselUrl;
  final String colorHex;
  final String colorSecundarioHex;
  final bool showSchedule;
  final bool showInCarousel;

  TvChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.imageUrl,
    this.logoCarouselUrl = '',
    this.colorHex = '#35ACE5',
    this.colorSecundarioHex = '#35ACE5',
    this.showSchedule = false,
    this.showInCarousel = false,
  });

  factory TvChannel.fromJson(Map<String, dynamic> json) {
    return TvChannel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Canal de TV en vivo',
      streamUrl: json['streamUrl'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      logoCarouselUrl: json['logoCarouselUrl'] ?? json['logo_carrusel'] ?? '',
      colorHex: json['colorHex'] ?? json['color_hex'] ?? '#35ACE5',
      colorSecundarioHex: json['colorSecundarioHex'] ?? json['color_secundario_hex'] ?? json['colorHex'] ?? json['color_hex'] ?? '#35ACE5',
      showSchedule: json['showSchedule'] ?? false,
      showInCarousel: json['showInCarousel'] ?? json['mostrar_en_carrusel'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'imageUrl': imageUrl,
        'logo_carrusel': logoCarouselUrl,
        'colorHex': colorHex,
        'colorSecundarioHex': colorSecundarioHex,
        'showSchedule': showSchedule,
        'mostrar_en_carrusel': showInCarousel,
      };

  TvChannel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? imageUrl,
    String? logoCarouselUrl,
    String? colorHex,
    String? colorSecundarioHex,
    bool? showSchedule,
    bool? showInCarousel,
  }) {
    return TvChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      logoCarouselUrl: logoCarouselUrl ?? this.logoCarouselUrl,
      colorHex: colorHex ?? this.colorHex,
      colorSecundarioHex: colorSecundarioHex ?? this.colorSecundarioHex,
      showSchedule: showSchedule ?? this.showSchedule,
      showInCarousel: showInCarousel ?? this.showInCarousel,
    );
  }
}
