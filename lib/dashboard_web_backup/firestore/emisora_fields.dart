abstract final class EmisoraFields {
  static const String collection = 'emisoras';
  static const String marcasCollection = 'marcas';
  static const String streamingsCollection = 'streamings';
  static const String programacionCollection = 'programacion';

  static const String ownerId = 'ownerId';

  static const String ownerEmail = 'ownerEmail';

  static const String nombre = 'nombre';
  static const String urlAudio = 'url_audio';
  static const String urlVideo = 'url_video';
  static const String colorHex = 'color_hex';
  static const String colorSecundarioHex = 'color_secundario_hex';
  static const String logoUrl = 'logo_url';
  /// Marca de tiempo de escritura en `logo_url`; la app móvil puede usarla para invalidar caché aunque la URL sea similar.
  static const String logoUrlUpdatedAt = 'logo_url_updated_at';
  static const String isVideo = 'isVideo';
  static const String mostrarProgramacion = 'mostrar_programacion';
  static const String socialWhatsapp = 'social_whatsapp';
  static const String socialInstagram = 'social_instagram';
  static const String socialFacebook = 'social_facebook';
  static const String socialX = 'social_x';
  static const String telefonoCabina = 'telefono_cabina';
  static const String showOnHome = 'show_on_home';
  static const String index = 'index';
  static const String appId = 'appId';
  static const String targetId = 'targetId';
  static const String dia = 'dia';
  static const String diaSemana = 'dia_semana';
  static const String horaInicio = 'hora_inicio';
  static const String horaFin = 'hora_fin';
  static const String startMinutes = 'start_minutes';
  static const String endMinutes = 'end_minutes';
  static const String locutor = 'locutor';
  static const String titulo = 'titulo';
  static const String lunes = 'lunes';
  static const String martes = 'martes';
  static const String miercoles = 'miercoles';
  static const String jueves = 'jueves';
  static const String viernes = 'viernes';
  static const String sabado = 'sabado';
  static const String domingo = 'domingo';
  static const String ultimaActualizacion = 'ultima_actualizacion';

  static const String nombreGrupo = 'nombre_grupo';
  static const String radioLabel = 'radio_label';
  static const String tvLabel = 'tv_label';
  static const String youtubeUrl = 'youtube_url';

  static const String splashUrl = 'splash_url';
  /// Clave en `marcas/{appId}` que lee la app móvil para el banner del Home. Valor `''` oculta el banner.
  static const String bannerHomeUrl = 'banner_home_url';
  static const String splashEnabled = 'splash_enabled';
  static const String splashDurationSec = 'splash_duration_sec';

  /// Payload del Flash Informativo en `marcas/{appId}` (clave legacy en Firestore: `alerta_global`).
  static const String flashInformativo = 'alerta_global';
  static const String flashInformativoMensaje = 'mensaje';
  static const String flashInformativoTimestamp = 'timestamp';
  static const String flashInformativoId = 'id_alerta';

  static const String stats = 'stats';
  static const String statsPlayCount = 'playCount';
}
