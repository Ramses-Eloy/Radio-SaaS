/// "www.x.net:8090/stream" sin esquema hace que Android tome el host como
/// protocolo (MalformedURLException). Se antepone https:// si falta.
String withScheme(String url) {
  final u = url.trim();
  return u.isEmpty || u.contains('://') ? u : 'https://$u';
}
