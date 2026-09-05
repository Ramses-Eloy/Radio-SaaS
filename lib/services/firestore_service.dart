import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/program.dart';
import '../models/station.dart';
import '../models/tv_channel.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Resolve `appId` in `marcas` collection for logged-in user `ownerEmail`
  Future<String?> resolveAppIdForOwner(String ownerEmail) async {
    final normalized = ownerEmail.trim().toLowerCase();
    if (normalized == 'isaacsarsanedas@gmail.com') return 'sira';
    if (normalized == 'ramses.11rsg@gmail.com') return 'erancon';
    try {
      final snap = await _db
          .collection('marcas')
          .where('ownerEmail', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.id;
      }
    } catch (_) {}
    return null;
  }

  // Real-time Stream for Brand Settings (`marcas` collection)
  Stream<Map<String, dynamic>?> streamMarca(String appId) {
    return _db.collection('marcas').doc(appId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!;
      }
      return null;
    });
  }

  // Real-time Stream for Emisoras (`emisoras` collection)
  Stream<List<Station>> streamEmisoras(String appId) {
    return _db.collection('emisoras').snapshots().map((snapshot) {
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final itemAppId = data['appId']?.toString().toLowerCase();
        return itemAppId == appId.toLowerCase() || doc.id.toLowerCase().startsWith('${appId.toLowerCase()}_');
      }).toList();

      return matchingDocs.map((doc) {
        final data = doc.data();
        return Station(
          id: doc.id,
          name: data['nombre'] ?? 'Emisora',
          slogan: data['slogan'] ?? 'La mejor música',
          logoUrl: data['logo_url'] ?? '',
          streamUrl: data['url_audio'] ?? '',
          videoStreamUrl: data['url_video'] ?? '',
          isLive: true,
          showSchedule: data['mostrar_programacion'] ?? true,
          whatsappNumber: data['social_whatsapp'] ?? '',
          phoneNumber: data['telefono_cabina'] ?? '',
          socialLinks: SocialLinks(
            facebook: data['social_facebook'] ?? '',
            instagram: data['social_instagram'] ?? '',
            twitter: data['social_x'] ?? '',
            tiktok: data['social_tiktok'] ?? '',
          ),
          lightTheme: ThemeConfig(
            primaryColorHex: data['color_hex'] ?? '#205CC6',
            secondaryColorHex: data['color_secundario_hex'] ?? data['color_hex'] ?? '#35ACE5',
            backgroundColorHex: '#F5F5F5',
            cardColorHex: '#FFFFFF',
          ),
          darkTheme: ThemeConfig(
            primaryColorHex: data['color_hex'] ?? '#205CC6',
            secondaryColorHex: data['color_secundario_hex'] ?? data['color_hex'] ?? '#35ACE5',
            backgroundColorHex: '#0D1117',
            cardColorHex: '#161B22',
          ),
        );
      }).toList();
    });
  }

  // Real-time Stream for TV Channels (`streamings` collection)
  Stream<List<TvChannel>> streamTvChannels(String appId) {
    return _db.collection('streamings').snapshots().map((snapshot) {
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final itemAppId = data['appId']?.toString().toLowerCase();
        return itemAppId == appId.toLowerCase() || doc.id.toLowerCase().startsWith('${appId.toLowerCase()}_');
      }).toList();

      return matchingDocs.map((doc) {
        final data = doc.data();
        return TvChannel(
          id: doc.id,
          name: data['nombre'] ?? 'Canal de TV',
          streamUrl: data['url_video'] ?? '',
          imageUrl: data['logo_url'] ?? '',
          colorHex: data['color_hex'] ?? '#35ACE5',
          showSchedule: data['mostrar_programacion'] ?? false,
          showInCarousel: data['mostrar_en_carrusel'] ?? false,
        );
      }).toList();
    });
  }

  // Stream current day programacion
  Stream<List<Program>> streamProgramacion(String targetId) {
    return _db
        .collection('programacion')
        .doc(targetId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() ?? {};
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      final dayKey = [
        'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'
      ][weekday - 1];

      final dailyList = data[dayKey] as List<dynamic>? ?? [];
      final programs = <Program>[];
      
      for (final item in dailyList) {
        if (item is Map<String, dynamic>) {
          // Parse time using old or new fields
          final rawTime = item['h']?.toString() ?? '';
          String startTime = item['hora_inicio']?.toString() ?? '00:00';
          String endTime = item['hora_fin']?.toString() ?? '23:59';

          if (rawTime.isNotEmpty && rawTime.contains('-')) {
            final parts = rawTime.split('-');
            startTime = parts[0].trim();
            if (parts.length > 1) endTime = parts[1].trim();
          } else if (rawTime.isNotEmpty) {
            startTime = rawTime.trim();
          }
          
          bool isLive = false;
          try {
            final now = DateTime.now();
            final startParts = startTime.split(':');
            final endParts = endTime.split(':');
            final start = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
            final end = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
            isLive = now.isAfter(start) && now.isBefore(end);
          } catch (_) {}

          final title = item['p']?.toString() ?? item['titulo']?.toString() ?? 'Programa';
          final host = item['t']?.toString() ?? item['locutor']?.toString() ?? 'Locutor';

          programs.add(Program(
            id: title,
            stationId: targetId,
            title: title,
            hostName: host,
            hostAvatarUrl: '',
            category: 'Programación',
            startTime: startTime,
            endTime: endTime,
            isLiveNow: isLive,
          ));
        }
      }
      return programs;
    });
  }

  // Update Marca Settings in Firestore
  Future<void> updateMarca({
    required String appId,
    required String nombreGrupo,
    required String logoUrl,
    required String colorHex,
    required String splashUrl,
    required String bannerHomeUrl,
    required bool splashEnabled,
    required int splashDurationSec,
    String radioLabel = 'En Vivo',
    String tvLabel = 'Video Live',
  }) async {
    await _db.collection('marcas').doc(appId).set({
      'appId': appId,
      'nombre_grupo': nombreGrupo,
      'logo_url': logoUrl,
      'splash_url': splashUrl,
      'banner_home_url': bannerHomeUrl,
      'splash_enabled': splashEnabled,
      'splash_duration_sec': splashDurationSec,
      'radio_label': radioLabel,
      'tv_label': tvLabel,
      'logo_url_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Create a new Emisora in `emisoras` collection
  Future<String> createEmisora({
    required String appId,
    required String nombre,
    required String ownerEmail,
  }) async {
    final ref = _db.collection('emisoras').doc();
    await ref.set({
      'appId': appId,
      'ownerEmail': ownerEmail,
      'nombre': nombre,
      'slogan': 'Música en vivo',
      'logo_url': 'https://i.postimg.cc/gc4QKX0F/logo.png',
      'color_hex': '#205CC6',
      'mostrar_programacion': true,
      'url_audio': '',
      'telefono_cabina': '',
      'social_whatsapp': '',
      'social_facebook': '',
      'social_instagram': '',
      'social_x': '',
    });
    return ref.id;
  }

  // Create a new Streaming TV Channel in `streamings` collection
  Future<String> createStreamingTv({
    required String appId,
    required String nombre,
    required String ownerEmail,
  }) async {
    final ref = _db.collection('streamings').doc();
    await ref.set({
      'appId': appId,
      'ownerEmail': ownerEmail,
      'nombre': nombre,
      'url_video': '',
      'logo_url': 'https://i.postimg.cc/NM9VLsVV/jurado.png',
      'mostrar_programacion': true,
      'isVideo': true,
    });
    return ref.id;
  }

  // Launch Flash Informativo (Pop-up) to `marcas` doc
  Future<void> triggerAlertaGlobal({
    required String appId,
    required String mensaje,
  }) async {
    final alertId = 'fi_${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('marcas').doc(appId).set({
      'alerta_global': {
        'appId': appId,
        'id_alerta': alertId,
        'mensaje': mensaje,
        'timestamp': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // Update Emisora details in Firestore
  Future<void> updateEmisora({
    required String stationId,
    required String appId,
    required String nombre,
    required String logoUrl,
    required String colorHex,
    String? colorSecundarioHex,
    required bool mostrarProgramacion,
    required String urlAudio,
    required String telefonoCabina,
    required String whatsapp,
    required String facebook,
    required String instagram,
    required String twitter,
  }) async {
    await _db.collection('emisoras').doc(stationId).set({
      'appId': appId,
      'nombre': nombre,
      'logo_url': logoUrl,
      'color_hex': colorHex,
      'color_secundario_hex': colorSecundarioHex ?? colorHex,
      'mostrar_programacion': mostrarProgramacion,
      'url_audio': urlAudio,
      'telefono_cabina': telefonoCabina,
      'social_whatsapp': whatsapp,
      'social_facebook': facebook,
      'social_instagram': instagram,
      'social_x': twitter,
    }, SetOptions(merge: true));
  }

  // Update Streaming TV details in Firestore
  Future<void> updateStreamingTv({
    required String channelId,
    required String appId,
    required String nombre,
    required String urlVideo,
    required String logoUrl,
    required bool mostrarProgramacion,
  }) async {
    await _db.collection('streamings').doc(channelId).set({
      'appId': appId,
      'nombre': nombre,
      'url_video': urlVideo,
      'logo_url': logoUrl,
      'mostrar_programacion': mostrarProgramacion,
      'isVideo': true,
    }, SetOptions(merge: true));
  }

  // Delete an Emisora from `emisoras` collection
  Future<void> deleteEmisora(String stationId) async {
    await _db.collection('emisoras').doc(stationId).delete();
  }

  // Delete a Streaming TV channel from `streamings` collection
  Future<void> deleteStreamingTv(String channelId) async {
    await _db.collection('streamings').doc(channelId).delete();
  }

  // Save weekly program schedule for a targetId in programacion collection
  Future<void> saveProgramacion({
    required String targetId,
    required String appId,
    required String ownerEmail,
    required Map<String, List<Map<String, String>>> weekSchedule,
  }) async {
    await _db.collection('programacion').doc(targetId).set({
      'appId': appId,
      'ownerEmail': ownerEmail,
      'targetId': targetId,
      'lunes': weekSchedule['Lunes'] ?? [],
      'martes': weekSchedule['Martes'] ?? [],
      'miercoles': weekSchedule['Miércoles'] ?? [],
      'jueves': weekSchedule['Jueves'] ?? [],
      'viernes': weekSchedule['Viernes'] ?? [],
      'sabado': weekSchedule['Sábado'] ?? [],
      'domingo': weekSchedule['Domingo'] ?? [],
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Stream program schedule doc from programacion collection
  Stream<Map<String, dynamic>?> streamProgramacionRaw(String targetId) {
    return _db.collection('programacion').doc(targetId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    });
  }

  // Ensure initial tenant collections exist in Firestore
  Future<void> ensureInitialDataSeeded(String appId) async {
    try {
      final marcaDoc = await _db.collection('marcas').doc(appId).get();
      if (!marcaDoc.exists) {
        if (appId == 'sira') {
          await updateMarca(
            appId: 'sira',
            nombreGrupo: 'Grupo Sira Radio',
            logoUrl: 'https://i.postimg.cc/gc4QKX0F/logo.png',
            colorHex: '#35ACE5',
            splashUrl: '',
            bannerHomeUrl: '',
            splashEnabled: true,
            splashDurationSec: 5,
          );
          await _db.collection('marcas').doc('sira').set({'ownerEmail': 'isaacsarsanedas@gmail.com'}, SetOptions(merge: true));

          await updateEmisora(
            stationId: 'sira_1',
            appId: 'sira',
            nombre: 'Radio Reforma 860 AM',
            logoUrl: 'https://i.postimg.cc/gc4QKX0F/logo.png',
            colorHex: '#35ACE5',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8124/stream',
            telefonoCabina: '9701033',
            whatsapp: 'https://wa.me/6679-1708',
            facebook: 'https://facebook.com',
            instagram: 'https://instagram.com',
            twitter: 'https://x.com',
          );
          await updateEmisora(
            stationId: 'sira_2',
            appId: 'sira',
            nombre: 'Hola Panamá 103.1 FM',
            logoUrl: 'https://i.postimg.cc/28RpbWC9/hola.png',
            colorHex: '#205CC6',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8124/stream',
            telefonoCabina: '9701033',
            whatsapp: 'https://wa.me/6679-1708',
            facebook: 'https://facebook.com',
            instagram: 'https://instagram.com',
            twitter: 'https://x.com',
          );
          await updateEmisora(
            stationId: 'sira_3',
            appId: 'sira',
            nombre: 'SIRA Radio Digital',
            logoUrl: 'https://i.postimg.cc/gc4QKX0F/logo.png',
            colorHex: '#35ACE5',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8124/stream',
            telefonoCabina: '9701033',
            whatsapp: 'https://wa.me/6679-1708',
            facebook: 'https://facebook.com',
            instagram: 'https://instagram.com',
            twitter: 'https://x.com',
          );
          await updateStreamingTv(
            channelId: 'sira_live',
            appId: 'sira',
            nombre: 'Jurado del Pueblo TV',
            urlVideo: 'https://www.youtube.com/live/C6aKV_ePz60',
            logoUrl: 'https://i.postimg.cc/NM9VLsVV/jurado.png',
            mostrarProgramacion: true,
          );
        } else {
          await updateMarca(
            appId: 'erancon',
            nombreGrupo: 'ERANCÓN',
            logoUrl: 'https://i.postimg.cc/QMK6Fvfb/EMPORIO.png',
            colorHex: '#5CE535',
            splashUrl: '',
            bannerHomeUrl: '',
            splashEnabled: true,
            splashDurationSec: 5,
          );
          await _db.collection('marcas').doc('erancon').set({'ownerEmail': 'ramses.11rsg@gmail.com'}, SetOptions(merge: true));

          await updateEmisora(
            stationId: 'erancon_1',
            appId: 'erancon',
            nombre: 'Fabulosa Estéreo 100.5',
            logoUrl: 'https://i.postimg.cc/8P5kqbK1/file-000.png',
            colorHex: '#FF3333',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8130/stream',
            telefonoCabina: '2643773',
            whatsapp: 'https://wa.me/6141-1005',
            facebook: 'https://www.facebook.com/fabulosa1005',
            instagram: 'https://www.instagram.com/fabulosa1005',
            twitter: 'https://x.com/Fabulosa1005',
          );
          await updateEmisora(
            stationId: 'erancon_2',
            appId: 'erancon',
            nombre: 'Emporio Radio 99.1',
            logoUrl: 'https://i.postimg.cc/QMK6Fvfb/EMPORIO.png',
            colorHex: '#5CE535',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8128/stream',
            telefonoCabina: '2643773',
            whatsapp: 'https://wa.me/6141-1005',
            facebook: 'https://facebook.com',
            instagram: 'https://instagram.com',
            twitter: 'https://x.com',
          );
          await updateEmisora(
            stationId: 'erancon_3',
            appId: 'erancon',
            nombre: 'Presidente 98.3 FM',
            logoUrl: 'https://i.postimg.cc/NM9VLsVV/jurado.png',
            colorHex: '#35ACE5',
            mostrarProgramacion: true,
            urlAudio: 'https://www.streaming507.net:8128/stream',
            telefonoCabina: '9701033',
            whatsapp: 'https://wa.me/6679-1708',
            facebook: 'https://facebook.com',
            instagram: 'https://instagram.com',
            twitter: 'https://x.com',
          );
          await updateStreamingTv(
            channelId: 'erancon_live',
            appId: 'erancon',
            nombre: 'Fabulosa Streaming TV',
            urlVideo: 'https://www.streaming507.net:2000/live',
            logoUrl: 'https://i.postimg.cc/8P5kqbK1/file-000.png',
            mostrarProgramacion: false,
          );
          await updateStreamingTv(
            channelId: 'erancon_live2',
            appId: 'erancon',
            nombre: 'Jurado del Pueblo TV',
            urlVideo: 'https://www.youtube.com/live/C6aKV_ePz60',
            logoUrl: 'https://i.postimg.cc/NM9VLsVV/jurado.png',
            mostrarProgramacion: true,
          );
        }
      }
    } catch (_) {}
  }
}
