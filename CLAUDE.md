# Radio SaaS (Radio White-Label)

Plataforma de radio por internet "marca blanca" con un solo código Flutter + Firebase:
la **app de oyentes** (Android/iOS) y el **dashboard web** (admins de emisora y superadmin).

## Cómo trabajar en este repo

- Responde siempre en **español**, conciso y directo. Sin narración ni relleno; comentarios en el código solo cuando aporten.
- Prefiere **la solución más simple** que funcione. Nada de abstracciones "por si acaso".
- **Minimiza lecturas/escrituras de Firestore** (plan Blaze, se paga por operación). Antes de añadir un `snapshots()`, un `get()` o un `Timer` que escriba, piensa cuántas veces se ejecuta por oyente y por día.
- Cada app móvil lee **solo los datos de su `appId`**. Nunca cargues datos de todas las marcas al arrancar.
- Todo cambio debe funcionar para **N emisoras**: nada de `if (appId == 'sira')` nuevos; la configuración vive en Firestore.

## Agentes (`.claude/agents/`)

Migrados de `.clinerules` (antes con Gemini). Flujo sugerido para pedidos grandes: `product-owner` → `arquitecto` → `desarrollador` → `tester`.

| Agente | Modelo | Rol |
|---|---|---|
| `product-owner` | opus | Estructura el pedido en tareas priorizadas. No escribe código. |
| `arquitecto` | opus | Diseña el cambio (archivos, Firestore, reglas). No escribe código. |
| `desarrollador` | sonnet | Implementa. |
| `tester` | sonnet | Corre análisis/pruebas y busca fallos de aislamiento entre marcas. |

## Modelo de negocio (multi-tenant)

- **Marca / tenant** = un cliente, identificado por `appId` (p. ej. `erancon`, `sira`). Documento `marcas/{appId}` con `ownerEmail`, branding, `features` y `alerta_global`.
- Cada marca publica **su propia app** = un *flavor* de Flutter (applicationId y ficha de tienda propios), todas contra el mismo proyecto Firebase `radio-saas-platform`.
- El **dueño de la emisora** entra al dashboard con su correo; el dashboard resuelve su marca por `marcas.ownerEmail`.
- El **superadmin** crea marcas, cambia correos de dueños y activa/desactiva módulos por marca (`features`: radio, tv, schedule, settings, multi-station → `lib/models/app_features.dart`).

## Colecciones de Firestore

| Colección | ID | Contenido |
|---|---|---|
| `marcas` | `{appId}` | Marca: dueño, branding, `features`, `alerta_global` |
| `emisoras` | `{appId}_{n}` | Estaciones de radio de la marca (URLs de audio, colores, redes) |
| `streamings` | `{appId}_...` | Canales de TV/video (YouTube, auto‑sync) |
| `programacion` | por emisora | Parrilla de programación |
| `stats_daily` | `{appId}_{YYYY-MM-DD}` | Telemetría agregada (contadores con `FieldValue.increment`) |

Todos los documentos por tenant llevan el campo `appId`; las consultas filtran por él.

## Estructura

```
lib/
  main.dart              Entry point principal. Móvil → app de oyentes. Web → dashboard (AdminDashboardScreen).
  web_main.dart          Entry point alternativo solo‑dashboard (no usado por defecto).
  admin/                 Puerta de auth del dashboard (login → superadmin o dueño).
  models/ providers/ screens/ widgets/ services/   App de oyentes (Provider).
    providers/station_provider.dart   Resuelve appId, escucha marca/emisoras/streamings.
    services/firestore_service.dart   Lecturas de la app móvil.
    services/telemetry_service.dart   Telemetría en memoria → flush cada 5 min a stats_daily.
  dashboard_web/         Dashboard (screens/*_workspace.dart, services/, superadmin/).
    superadmin/services/superadmin_repository.dart   Gestión de marcas; correo del superadmin.
functions/index.js       Cloud Functions v1 (Node 20): createBrand, createStation,
                         createStreamingChannel, updateUserCredentials, syncYouTubeStreams (cada 5 min),
                         sendAvanceInformativoPush (FCM topic brand_{appId}), resolveYouTubeChannelId.
functions/*.js sueltos   Scripts de mantenimiento de un solo uso (fix_station, set_cors, test_id); no se despliegan.
firestore.rules storage.rules firebase.json   Reglas y hosting (build/web).
android/app/build.gradle.kts   productFlavors: erancon (com.erancon.radio), sira (com.gruposira.radio).
flutter_launcher_icons-<flavor>.yaml, assets/icons/<flavor>/   Iconos por flavor.
Legal/, DEPLOYMENT_GUIDELINES.md   Textos legales y guía de publicación en tiendas.
```

El `appId` de la app móvil se decide en `_determineAppId()` (`lib/main.dart`): `--dart-define=APP_ID=...`, o el nombre de paquete, con `erancon` por defecto.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
dart format lib test

# App de oyentes (Android), por flavor
flutter run --flavor erancon
flutter build appbundle --release --flavor sira

# Iconos de un flavor
dart run flutter_launcher_icons -f flutter_launcher_icons-sira.yaml

# Dashboard web (usa lib/main.dart) y despliegue
flutter build web --release
firebase deploy --only hosting
firebase deploy --only functions      # desde la raíz; código en functions/
firebase deploy --only firestore:rules,storage
```

Los `firebase deploy` afectan a producción de **todas** las emisoras: no los ejecutes sin que el usuario lo pida.

## Cuidado con

- `test/widget_test.dart` construye `RadioWhiteLabelApp()` sin `initialAppId`, así que `flutter test` no compila hasta arreglarlo.
- El correo del superadmin está repetido en `superadmin_repository.dart` y en cada función de `functions/index.js` (`createBrand` acepta además un segundo correo). Si cambia, cámbialo en todos.
- `firestore.rules` permite escribir **cualquier** documento a cualquier usuario autenticado, y `stats_daily` a cualquiera. El aislamiento entre tenants hoy solo lo hace el cliente.
- `android/app/google-services.json` y `lib/firebase_options.dart` son configuración pública de Firebase; los keystores (`*.jks`, `android/key.properties`) nunca se suben.
- iOS todavía no tiene flavors (un solo bundle id en `ios/Runner.xcodeproj`).
