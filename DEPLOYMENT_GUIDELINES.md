# 🚀 Guía Maestra de Deploy & Políticas de Publicación
## Radio White-Label (Google Play Store & Apple App Store)

Este documento contiene todos los requisitos, políticas, textos legales, configuraciones de consola y recomendaciones estratégicas diseñadas **específicamente para esta aplicación de Radio White-Label** para garantizar una aprobación rápida y sin rechazos en **Google Play Store (Android)** y **Apple App Store (iOS)**.

---

## 📌 1. Diagnóstico de la Aplicación (¿Qué tiene y qué no tiene?)

| Característica | Estado en Móvil | Impacto en Políticas de Tienda |
| :--- | :--- | :--- |
| **Autenticación / Cuentas de Usuario** | ❌ **No tiene (App pública)** | **No requiere** botón de "Eliminar cuenta" en la app ni URL de borrado web. Acceso total para revisores sin credenciales. |
| **Audio en Segundo Plano (Lockscreen / Background)** | ✅ **Sí (`just_audio_background`)** | Requiere declarar `FOREGROUND_SERVICE_MEDIA_PLAYBACK` en Android y `UIBackgroundModes: audio` en iOS. |
| **Dashboard Administrativo** | 🌐 **Solo Web / Admin** | **No forma parte de la app móvil.** No se deben enviar credenciales del dashboard ni mencionarlo como requisito de la app móvil. |
| **Video / TV Streaming** | ✅ **Sí (`video_player` / PiP)** | Debe cumplir con políticas de derechos de autor y reproducción de video sin violar términos de terceros. |
| **Publicidad / Banners Internos** | ✅ **Sí (Splash Ad Dialog / Banners)** | Requiere declarar en la consola si la app contiene anuncios (publicidad propia de la emisora). |
| **Arquitectura White-Label (Marcas múltiples)** | ✅ **Sí (Erancon, Sira, etc.)** | Requiere atención crítica a la directiva **Guideline 4.3 (Spam / Clones)** de Apple. |

---

## ⚠️ 2. Recomendaciones Críticas Antes del Envío a Revisión

### A. 📻 Reemplazo de Links de YouTube por Streaming Directo (Crucial)
*   **El Riesgo:** Las políticas de Google Play y los Términos de Servicio de la API de YouTube prohíben terminantemente reproducir audio de YouTube en segundo plano o con la pantalla apagada. Como la app tiene servicios multimedia en segundo plano activos, si el revisor detecta que la señal proviene de YouTube y sigue sonando con la pantalla bloqueada, **rechazará la app de inmediato**.
*   **La Solución:** 
    1. Durante la fase de revisión y lanzamiento, configura como señal principal un **stream de audio oficial directo** (Icecast, Shoutcast, HLS / `.m3u8`, AAC o MP3).
    2. Asegúrate de que la URL sea **`https://`** para cumplir con el estándar *App Transport Security (ATS)* de Apple.
    3. Si deseas incluir canales de YouTube, déjalos en una sección secundaria de visualización de videos donde la reproducción se detenga al salir de la pantalla.

### B. 🍏 Prevención del Rechazo 4.3 de Apple (Spam / Apps Clonadas)
Apple rechaza aplicaciones que sean copias idénticas con diferente logo subidas desde una misma cuenta de desarrollador.
*   **Estrategia Recomendada 1 (App Contenedora / Multi-estación):** Publicar una app principal en App Store que permita al oyente elegir su estación favorita o ingresar el identificador de su radio.
*   **Estrategia Recomendada 2 (Cuentas Individuales):** Si cada cliente desea su propia app independiente con su propio nombre en la App Store, la app debe publicarse desde la **cuenta de Apple Developer del cliente/empresa**, no desde una cuenta única que acumule decenas de radios idénticas.

### C. 🔒 Transmisiones y Enlaces Seguros (HTTPS Obligatorio)
*   Tanto iOS como Android (desde Android 9) bloquean por defecto el tráfico no cifrado (`http://`).
*   Verifica que la URL del stream de radio, el servidor de imágenes de Firebase Storage y cualquier web enlazada usen certificado SSL válido (`https://`).

---

## 📋 3. Documentos y Enlaces Legales Requeridos

Debes tener estas páginas publicadas en internet (por ejemplo, en el hosting de tu web/dashboard o Firebase Hosting) antes de enviar la app:

### 1. URL de Política de Privacidad (Privacy Policy) — *Obligatoria*
Debe ser una página web pública que detalle:
*   **Nombre de la App / Empresa.**
*   **Datos que se recopilan:** Identificadores únicos de instalación (para Firebase Analytics/Crashlytics), registros técnicos de conectividad al stream.
*   **Aclaración de cuenta:** Indicar explícitamente que la aplicación no requiere registro ni recopila nombres, correos o contraseñas de los oyentes.
*   **Servicios de terceros:** Firebase Core, Cloud Firestore, Firebase Storage.
*   **Contacto:** Correo electrónico de soporte técnico.

### 2. URL de Soporte y Contacto (Support URL) — *Obligatoria en iOS*
*   Una página simple con información de contacto, preguntas frecuentes o formulario de ayuda para los oyentes.

---

## 🤖 4. Guía de Configuración: Google Play Console (Android)

### A. Acceso a Aplicaciones (App Access)
*   Selecciona: **"Todas las funciones están disponibles sin restricciones de acceso o inicio de sesión"**.

### B. Seguridad de los Datos (Data Safety Form)
Responde al cuestionario de la siguiente manera:
1.  *¿Tu aplicación recopila o comparte alguno de los tipos de datos de usuario obligatorios?* -> **Sí** (por Firebase Analytics / Diagnóstico de fallos).
2.  *¿Todos los datos que recopila tu aplicación se cifran en tránsito?* -> **Sí** (mediante protocolo HTTPS).
3.  *¿Tu aplicación permite a los usuarios crear una cuenta?* -> **No**.
4.  *Tipos de datos:*
    *   **Ubicación:** No (a menos que uses GPS, no aplica).
    *   **Información personal:** No.
    *   **Rendimiento y diagnósticos de la app (Crash logs / Diagnostics):** Sí (para fines de análisis y funcionamiento de la app).
    *   **Identificadores de dispositivo (Device or other IDs):** Sí (identificador anónimo de instalación de Firebase).

### C. Declaración de Servicio en Primer Plano (`FOREGROUND_SERVICE`)
Google Play Console solicitará justificar el permiso `FOREGROUND_SERVICE_MEDIA_PLAYBACK`:
*   **Tipo de servicio:** Reproducción de contenido multimedia (`mediaPlayback`).
*   **Justificación escrita:**
    > *"Nuestra aplicación es una emisora de radio en vivo. El servicio en primer plano de reproducción multimedia es esencial para permitir que los oyentes sigan escuchando la transmisión de audio continua en tiempo real mientras usan otras aplicaciones o cuando el dispositivo tiene la pantalla bloqueada, ofreciendo controles de reproducción estándar (reproducir/pausar) en el área de notificaciones del sistema."*
*   **Video de demostración:** Sube a YouTube (modo no listado) o Google Drive un video de ~30 segundos grabando la pantalla del móvil donde se vea:
    1. Abrir la app y pulsar Play en la radio.
    2. Salir de la app a la pantalla de inicio o bloquear el teléfono.
    3. Mostrar que la notificación multimedia sigue activa y permite pausar y reanudar el audio.

### D. Declaración de Anuncios
*   En *Contenido de la app -> Anuncios*, si muestras popups internos de patrocinadores de la radio, marca **"Sí, mi aplicación contiene anuncios"**.

---

## 🍏 5. Guía de Configuración: Apple App Store Connect (iOS)

### A. Información para la Revisión (App Review Information)
*   **¿Requiere inicio de sesión? (Sign-in required):** **Desmarcado / No**.
*   **Notas para el Revisor (Review Notes):** Copia y pega el siguiente texto en inglés:

```text
This app is a public live radio and video streaming application designed for our listeners.

All features, including live audio broadcast, TV/video streaming, daily programming schedule, and station info, are publicly accessible without requiring any user registration or authentication.

To test the application:
1. Open the app to view the station player.
2. Tap the Play button to start the live audio stream.
3. The app fully supports background audio playback via iOS lock screen and Control Center media controls.
4. You can navigate through the schedule and station settings tabs freely.
```

### B. Privacidad de la App (App Privacy Questionnaire)
*   Declara que la app recopila únicamente **"Datos de diagnóstico / Diagnósticos de fallos"** y **"Datos de uso"** no vinculados a la identidad del usuario (asociados a Firebase).

### C. Clasificación por Edad (Age Rating)
*   Completa el cuestionario indicando que la app no contiene violencia ni apuestas.
*   En *"Acceso web sin restricciones"*, marca **No** (los enlaces de redes sociales abren mediante navegador externo vía `url_launcher`).
*   La clasificación resultante suele ser **4+** o **9+** (debido al contenido de streaming en vivo).

---

## 🎨 6. Especificaciones de Recursos Gráficos y Metadatos

### Tabla de Medidas Exactas

| Recurso | Plataforma | Dimensiones / Formato | Notas Importantes |
| :--- | :--- | :--- | :--- |
| **Icono de Tienda** | Google Play | **512 x 512 px** (PNG 32-bit) | Sin canal alfa / transparencia. Peso máx. 1024 KB. |
| **Icono de Tienda** | App Store | **1024 x 1024 px** (PNG) | Sin canal alfa / transparencia. Sin bordes redondeados (Apple los aplica). |
| **Gráfico de Funciones** | Google Play | **1024 x 500 px** (JPG o PNG) | Banner promocional superior en Play Store. |
| **Capturas iPhone 6.7"** | App Store | **1290 x 2796 px** (o 1284 x 2778 px) | Obligatorias para modelos iPhone 15/14 Pro Max. |
| **Capturas iPhone 6.5"** | App Store | **1242 x 2688 px** (o 1284 x 2778 px) | Obligatorias para pantallas sin botón Home. |
| **Capturas iPad 12.9"** | App Store | **2048 x 2732 px** | Obligatorias si habilitas soporte para iPad. |
| **Capturas Android Móvil** | Google Play | Mínimo 2 capturas (ej. **1080 x 2400 px**) | Relación de aspecto 16:9 o 9:16. |

### Metadatos de la Ficha (Textos Sugeridos)

*   **Nombre de la App (Máx. 30 caracteres):** `[Nombre Radio] - Radio En Vivo`
*   **Subtítulo (iOS - Máx. 30 caracteres):** `Música, Noticias y TV en Vivo`
*   **Descripción Corta (Android - Máx. 80 caracteres):** `Escucha la transmisión en vivo de [Nombre Radio], programación y TV online.`
*   **Descripción Completa:**
    ```text
    ¡Bienvenido a la aplicación oficial de [Nombre de la Radio]!

    Lleva la mejor música, noticias, entretenimiento y programación en vivo directamente en tu dispositivo móvil las 24 horas del día.

    Características principales:
    📻 Transmisión en Vivo: Escucha la señal de audio en alta fidelidad y sin interrupciones.
    🎵 Reproducción en Segundo Plano: Continúa disfrutando de tu radio favorita mientras utilizas otras aplicaciones o con la pantalla bloqueada.
    📅 Programación al Día: Conoce los horarios y presentadores de todos tus programas favoritos.
    📺 TV / Streaming en Directo: Disfruta de nuestras transmisiones especiales en video y cobertura en tiempo real.
    ⏰ Temporizador de Apagado (Sleep Timer): Programa el apagado automático de la radio para dormir escuchando tu música preferida.
    🌐 Redes Sociales y Contacto: Conéctate con nosotros a través de WhatsApp y nuestras plataformas oficiales con un solo toque.

    Descárgala ahora y sé parte de nuestra comunidad de oyentes estés donde estés.
    ```
*   **Palabras Clave / Keywords (iOS - Máx. 100 caracteres):** `radio,musica,envivo,streaming,noticias,emisora,estacion,online,live,audio`

---

## 🛠️ 7. Checklist Técnico en el Código antes de Compilar

Antes de generar el archivo `.aab` (Android) o el archivo `.ipa` / Archive (iOS):

- [ ] **Versión del Proyecto:** Incrementar `version: 1.0.0+1` en `pubspec.yaml` para cada nueva subida.
- [ ] **Stream HTTPS:** Verificar que la URL de streaming en Firestore o configuración use `https://`.
- [ ] **Audio en Segundo Plano en iOS:** Asegurar que `ios/Runner/Info.plist` tenga configurada la clave `UIBackgroundModes` con `<string>audio</string>`.
- [ ] **Permiso de Notificaciones en Android:** Asegurar que `AndroidManifest.xml` incluya `POST_NOTIFICATIONS` y `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- [ ] **Modo Release:** Validar que `debugShowCheckedModeBanner` esté en `false` y no haya prints/logs con información sensible.
- [ ] **Iconos Generados:** Ejecutar `dart run flutter_launcher_icons` con los iconos específicos de la marca/radio.

---

## 💡 8. Ideas y Sugerencias para Futuras Versiones

1.  **Metadatos Dinámicos en Pantalla de Bloqueo (Now Playing Info):**
    *   Conectar el stream a la API de Icecast/Shoutcast para mostrar el título de la canción y artista actual en la notificación y pantalla de bloqueo automáticamente.
2.  **Notificaciones Push Segmentadas (FCM):**
    *   Enviar alertas automáticas cuando comience un programa estelar de la radio.
3.  **Favoritos y Grabación de Podcasts:**
    *   Permitir a los oyentes guardar programas anteriores para escucharlos bajo demanda (On-Demand).
