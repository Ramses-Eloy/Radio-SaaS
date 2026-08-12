enum EmisoraDocType {
  brandInfo,
  radioAudio,
  liveVideo,
  unknown,
}

class EmisoraId {
  EmisoraId._();

  static bool isBrandInfo({required String appId, required String id}) => id == '${appId}_info';

  static bool isLive({required String appId, required String id}) => id == '${appId}_live';

  static bool isRadioNumeric({required String appId, required String id}) {
    final prefix = '${appId}_';
    if (!id.startsWith(prefix)) return false;
    final rest = id.substring(prefix.length);
    if (rest.isEmpty) return false;
    // Acepta solo sufijos numéricos: _1, _2, ...
    return int.tryParse(rest) != null;
  }

  static EmisoraDocType typeOf({required String appId, required String id}) {
    if (isBrandInfo(appId: appId, id: id)) return EmisoraDocType.brandInfo;
    if (isLive(appId: appId, id: id)) return EmisoraDocType.liveVideo;
    if (isRadioNumeric(appId: appId, id: id)) return EmisoraDocType.radioAudio;
    return EmisoraDocType.unknown;
  }
}

