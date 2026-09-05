/// Configuración modular de características activas para cada marca (Tenant).
/// Controla la visibilidad de pantallas en la App Móvil y secciones en el Dashboard.
class AppFeatures {
  final bool enableRadio;
  final bool enableTv;
  final bool enableSchedule;
  final bool enableSettings;
  final bool enableMultiStation;

  const AppFeatures({
    this.enableRadio = true,
    this.enableTv = false,
    this.enableSchedule = false,
    this.enableSettings = true,
    this.enableMultiStation = false,
  });

  /// Preset: Modo Solo Player (Plan Básico / Sencillo)
  /// Solo reproductor de audio, redes sociales y ajustes mínimos.
  factory AppFeatures.presetSoloPlayer() {
    return const AppFeatures(
      enableRadio: true,
      enableTv: false,
      enableSchedule: false,
      enableSettings: true,
      enableMultiStation: false,
    );
  }

  /// Preset: Modo Full Suite (Plan Pro / Todo incluido)
  /// Radio + Canales de Video/TV + Parrilla de Programación + Ajustes + Multi-Emisora.
  factory AppFeatures.presetFullSuite() {
    return const AppFeatures(
      enableRadio: true,
      enableTv: true,
      enableSchedule: true,
      enableSettings: true,
      enableMultiStation: true,
    );
  }

  /// Determina si la app está en modo "Solo Player" (1 sola pantalla activa: Radio).
  bool get isSoloPlayer =>
      enableRadio && !enableTv && !enableSchedule && !enableSettings;

  /// Cuenta cuántas pantallas principales están activas.
  int get activeScreensCount {
    int count = 0;
    if (enableRadio) count++;
    if (enableSchedule) count++;
    if (enableTv) count++;
    if (enableSettings) count++;
    return count;
  }

  /// Construye una instancia a partir de un mapa de Firestore.
  /// Si el mapa es nulo o faltan claves, aplica valores por defecto seguros
  /// (Full Suite para retrocompatibilidad con marcas existentes sin `features`).
  factory AppFeatures.fromMap(Map<String, dynamic>? map) {
    if (map == null || !map.containsKey('features') || map['features'] is! Map) {
      // Retro-compatibility: if no features map exists, assume it's an old brand with all features.
      return AppFeatures.presetFullSuite();
    }

    final data = Map<String, dynamic>.from(map['features'] as Map);

    return AppFeatures(
      enableRadio:
          data['enable_radio'] as bool? ?? data['enableRadio'] as bool? ?? true,
      enableTv:
          data['enable_tv'] as bool? ?? data['enableTv'] as bool? ?? false,
      enableSchedule: data['enable_schedule'] as bool? ??
          data['enableSchedule'] as bool? ??
          false,
      enableSettings: data['enable_settings'] as bool? ??
          data['enableSettings'] as bool? ??
          true,
      enableMultiStation: data['enable_multi_station'] as bool? ??
          data['enableMultiStation'] as bool? ??
          false,
    );
  }

  /// Convierte a un mapa listo para persistir en Firestore (`marcas/{appId}.features`).
  Map<String, dynamic> toMap() {
    return {
      'enable_radio': enableRadio,
      'enable_tv': enableTv,
      'enable_schedule': enableSchedule,
      'enable_settings': enableSettings,
      'enable_multi_station': enableMultiStation,
    };
  }

  AppFeatures copyWith({
    bool? enableRadio,
    bool? enableTv,
    bool? enableSchedule,
    bool? enableSettings,
    bool? enableMultiStation,
  }) {
    return AppFeatures(
      enableRadio: enableRadio ?? this.enableRadio,
      enableTv: enableTv ?? this.enableTv,
      enableSchedule: enableSchedule ?? this.enableSchedule,
      enableSettings: enableSettings ?? this.enableSettings,
      enableMultiStation: enableMultiStation ?? this.enableMultiStation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppFeatures &&
        other.enableRadio == enableRadio &&
        other.enableTv == enableTv &&
        other.enableSchedule == enableSchedule &&
        other.enableSettings == enableSettings &&
        other.enableMultiStation == enableMultiStation;
  }

  @override
  int get hashCode => Object.hash(
        enableRadio,
        enableTv,
        enableSchedule,
        enableSettings,
        enableMultiStation,
      );
}
