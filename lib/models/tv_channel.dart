class TvChannel {
  final String id;
  final String name;
  final String streamUrl;
  final String imageUrl;
  final String colorHex;
  final String colorSecundarioHex;
  final bool showOnHome;
  final bool showSchedule;

  TvChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.imageUrl,
    this.colorHex = '#35ACE5',
    this.colorSecundarioHex = '#35ACE5',
    this.showOnHome = true,
    this.showSchedule = false,
  });

  factory TvChannel.fromJson(Map<String, dynamic> json) {
    return TvChannel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Canal de TV en vivo',
      streamUrl: json['streamUrl'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      colorHex: json['colorHex'] ?? json['color_hex'] ?? '#35ACE5',
      colorSecundarioHex: json['colorSecundarioHex'] ?? json['color_secundario_hex'] ?? json['colorHex'] ?? json['color_hex'] ?? '#35ACE5',
      showOnHome: json['showOnHome'] ?? true,
      showSchedule: json['showSchedule'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'imageUrl': imageUrl,
        'colorHex': colorHex,
        'colorSecundarioHex': colorSecundarioHex,
        'showOnHome': showOnHome,
        'showSchedule': showSchedule,
      };

  TvChannel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? imageUrl,
    String? colorHex,
    String? colorSecundarioHex,
    bool? showOnHome,
    bool? showSchedule,
  }) {
    return TvChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      colorHex: colorHex ?? this.colorHex,
      colorSecundarioHex: colorSecundarioHex ?? this.colorSecundarioHex,
      showOnHome: showOnHome ?? this.showOnHome,
      showSchedule: showSchedule ?? this.showSchedule,
    );
  }
}
