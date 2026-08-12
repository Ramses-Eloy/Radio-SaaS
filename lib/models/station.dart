import 'package:flutter/material.dart';

class ThemeConfig {
  final String primaryColorHex;
  final String secondaryColorHex;
  final String backgroundColorHex;
  final String cardColorHex;

  ThemeConfig({
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.backgroundColorHex,
    required this.cardColorHex,
  });

  Color get primaryColor => parseColor(primaryColorHex, const Color(0xFF205CC6));
  Color get secondaryColor => parseColor(secondaryColorHex, const Color(0xFF35ACE5));
  Color get backgroundColor => parseColor(backgroundColorHex, const Color(0xFF0D1117));
  Color get cardColor => parseColor(cardColorHex, const Color(0xFF161B22));

  static Color parseColor(String hexString, Color fallback) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      primaryColorHex: json['primaryColorHex'] ?? '#205CC6',
      secondaryColorHex: json['secondaryColorHex'] ?? '#35ACE5',
      backgroundColorHex: json['backgroundColorHex'] ?? '#0D1117',
      cardColorHex: json['cardColorHex'] ?? '#161B22',
    );
  }

  Map<String, dynamic> toJson() => {
        'primaryColorHex': primaryColorHex,
        'secondaryColorHex': secondaryColorHex,
        'backgroundColorHex': backgroundColorHex,
        'cardColorHex': cardColorHex,
      };
}

class SocialLinks {
  final String instagram;
  final String facebook;
  final String tiktok;
  final String twitter;

  SocialLinks({
    this.instagram = '',
    this.facebook = '',
    this.tiktok = '',
    this.twitter = '',
  });

  factory SocialLinks.fromJson(Map<String, dynamic> json) {
    return SocialLinks(
      instagram: json['instagram'] ?? '',
      facebook: json['facebook'] ?? '',
      tiktok: json['tiktok'] ?? '',
      twitter: json['twitter'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'instagram': instagram,
        'facebook': facebook,
        'tiktok': tiktok,
        'twitter': twitter,
      };
}

class Station {
  final String id;
  final String name;
  final String slogan;
  final String logoUrl;
  final String streamUrl;
  final String videoStreamUrl;
  final bool isLive;
  final bool showSchedule;
  final String whatsappNumber;
  final String phoneNumber;
  final SocialLinks socialLinks;
  final ThemeConfig lightTheme;
  final ThemeConfig darkTheme;

  Station({
    required this.id,
    required this.name,
    required this.slogan,
    required this.logoUrl,
    required this.streamUrl,
    this.videoStreamUrl = '',
    this.isLive = true,
    this.showSchedule = true,
    required this.whatsappNumber,
    required this.phoneNumber,
    required this.socialLinks,
    required this.lightTheme,
    required this.darkTheme,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Hola Panamá',
      slogan: json['slogan'] ?? 'La mejor música',
      logoUrl: json['logoUrl'] ?? 'https://i.postimg.cc/28RpbWC9/hola.png',
      streamUrl: json['streamUrl'] ?? 'https://www.streaming507.net:8124/stream',
      videoStreamUrl: json['videoStreamUrl'] ?? '',
      isLive: json['isLive'] ?? true,
      showSchedule: json['showSchedule'] ?? true,
      whatsappNumber: json['whatsappNumber'] ?? 'https://wa.me/6679-1708',
      phoneNumber: json['phoneNumber'] ?? '9701033',
      socialLinks: SocialLinks.fromJson(json['socialLinks'] ?? {}),
      lightTheme: ThemeConfig.fromJson(json['lightTheme'] ?? {
        'primaryColorHex': '#205CC6',
        'secondaryColorHex': '#35ACE5',
        'backgroundColorHex': '#F5F5F5',
        'cardColorHex': '#FFFFFF',
      }),
      darkTheme: ThemeConfig.fromJson(json['darkTheme'] ?? {
        'primaryColorHex': '#205CC6',
        'secondaryColorHex': '#35ACE5',
        'backgroundColorHex': '#0D1117',
        'cardColorHex': '#161B22',
      }),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slogan': slogan,
        'logoUrl': logoUrl,
        'streamUrl': streamUrl,
        'videoStreamUrl': videoStreamUrl,
        'isLive': isLive,
        'showSchedule': showSchedule,
        'whatsappNumber': whatsappNumber,
        'phoneNumber': phoneNumber,
        'socialLinks': socialLinks.toJson(),
        'lightTheme': lightTheme.toJson(),
        'darkTheme': darkTheme.toJson(),
      };

  Station copyWith({
    String? id,
    String? name,
    String? slogan,
    String? logoUrl,
    String? streamUrl,
    String? videoStreamUrl,
    bool? isLive,
    bool? showSchedule,
    String? whatsappNumber,
    String? phoneNumber,
    SocialLinks? socialLinks,
    ThemeConfig? lightTheme,
    ThemeConfig? darkTheme,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      slogan: slogan ?? this.slogan,
      logoUrl: logoUrl ?? this.logoUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      videoStreamUrl: videoStreamUrl ?? this.videoStreamUrl,
      isLive: isLive ?? this.isLive,
      showSchedule: showSchedule ?? this.showSchedule,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      socialLinks: socialLinks ?? this.socialLinks,
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
    );
  }
}
