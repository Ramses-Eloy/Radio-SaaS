---
name: nueva-emisora
description: Pasos para dar de alta la app de un cliente nuevo (marca/appId) como flavor de Android. Úsalo cuando el usuario pida crear, agregar o publicar la app de una emisora o marca nueva.
---

# Alta de una emisora/marca nueva

Necesitas del usuario: `appId` (minúsculas, sin espacios), nombre visible de la app, `applicationId` (p. ej. `com.cliente.radio`) y el icono (PNG 1024x1024 y su versión foreground).

1. **Datos en Firestore**: la marca se crea desde el dashboard del superadmin (Cloud Function `createBrand`), que genera `marcas/{appId}` y `emisoras/{appId}_1`. No escribas estos documentos a mano ni añadas datos de ejemplo en código.
2. **Flavor Android**: en `android/app/build.gradle.kts`, dentro de `productFlavors`, copia el bloque de `sira` con el nuevo nombre, `applicationId` y `resValue("string", "app_name", ...)`.
3. **appId en la app**: en `_determineAppId()` de `lib/main.dart` añade la línea que mapea el paquete al `appId` (igual que `erancon` y `sira`). Alternativa sin tocar código: compilar con `--dart-define=APP_ID=<appId>`.
4. **Iconos**: pon `icon.png` e `icon_foreground.png` en `assets/icons/<appId>/`, crea `flutter_launcher_icons-<appId>.yaml` copiando el de `sira`, y ejecuta `dart run flutter_launcher_icons -f flutter_launcher_icons-<appId>.yaml`. Crea `android/app/src/<appId>/res/values/colors.xml` si el generador no lo hace.
5. **Firebase**: el usuario registra la app Android con el nuevo `applicationId` en la consola de Firebase (`radio-saas-platform`) y reemplaza `android/app/google-services.json` por el descargado (incluye todas las apps). Tú no puedes hacer este paso.
6. **Verificar**: `flutter analyze` y `flutter build appbundle --release --flavor <appId>`.
7. **Tienda**: textos y formularios en `DEPLOYMENT_GUIDELINES.md` y `Legal/`.

No agregues `if (appId == '<nuevo>')` en providers ni servicios: todo lo específico de la marca vive en `marcas/{appId}`.
