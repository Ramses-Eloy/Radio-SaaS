# Guía de Privacidad de la App (App Store Connect)

Este documento contiene las respuestas que debes proveer en **App Store Connect** dentro de la sección de **Privacidad de la App (App Privacy)** de tu aplicación.

## 1. Recolección de Datos (Data Collection)
- **¿Tú o tus socios externos recopilan datos a través de esta app?**
  - **Respuesta:** SÍ.

## 2. Tipos de Datos Recopilados
Deberás seleccionar los siguientes tipos de datos en la lista de App Store Connect:

### Ubicación (Location)
- Selecciona **Ubicación aproximada (Coarse Location)**.
  - *Cómo se usa:* Analytics (Estadísticas de la aplicación).
  - *¿Se vincula con el usuario? (Linked to user):* NO.
  - *¿Se usa para rastreo? (Tracking):* NO.

### Datos de uso (Usage Data)
- Selecciona **Interacción con el producto (Product Interaction)** (clics en botones, reproducciones de streaming).
  - *Cómo se usa:* Analytics (Estadísticas de la aplicación).
  - *¿Se vincula con el usuario? (Linked to user):* NO.
  - *¿Se usa para rastreo? (Tracking):* NO.

## 3. Resumen Final de Privacidad
Una vez llenes el cuestionario, Apple generará un resumen de privacidad (las etiquetas de privacidad de la App Store) que mostrará que la aplicación recopila:
1. Datos no vinculados al usuario (Data Not Linked to You).
2. Ubicación aproximada (Coarse Location).
3. Datos de uso (Usage Data).

**Nota de Seguridad:** Dado que marcaste que los datos **NO** están vinculados al usuario, Apple no requiere que implementes la función de eliminación de cuentas, lo que encaja perfectamente con el flujo de tu aplicación de radio que no requiere registro.
