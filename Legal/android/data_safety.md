# Guía de Seguridad de Datos (Google Play Data Safety)

Este documento contiene las respuestas que debes proveer en la consola de Google Play (Google Play Console) en la sección de **Contenido de la aplicación > Seguridad de los datos (Data Safety)**.

## 1. Resumen de recolección de datos
- **¿Tu aplicación recopila o comparte alguno de los tipos de datos de usuarios requeridos?** 
  - **Respuesta:** SÍ.
- **¿Todos los datos de los usuarios recopilados por tu aplicación están encriptados en tránsito?** 
  - **Respuesta:** SÍ (Se usa HTTPS/TLS para enviar telemetría a Firebase).
- **¿Proporcionas una forma para que los usuarios soliciten que se borren sus datos?** 
  - **Respuesta:** Puedes responder que NO se aplica o que SÍ proporcionas un mecanismo, pero dado que los datos son totalmente anónimos y no están vinculados a una cuenta o identidad, es imposible borrar los datos de un usuario en específico. Lo ideal es marcar que **la aplicación no permite a los usuarios crear una cuenta** y que los datos recopilados son anónimos.

## 2. Tipos de Datos
Debes seleccionar las siguientes categorías:

### Ubicación
- **Ubicación aproximada (Approximate location):** 
  - Recopilado: **SÍ**
  - Compartido: **NO**
  - ¿Se procesan estos datos de forma efímera?: **NO** (se guardan como una métrica en el dashboard).
  - ¿Es necesario?: **Opcional / Requerido** (Depende de si permites apagar las analíticas, si no, es requerido).
  - Propósito: **Estadísticas (Analytics)**.
  - *Nota interna:* La app solo lee el código de país del Locale del teléfono, pero a los ojos de Google Play, inferir el país se considera ubicación aproximada.

### Actividad de la aplicación (App activity)
- **Interacciones con la aplicación (App interactions):** 
  - Recopilado: **SÍ**
  - Compartido: **NO**
  - Propósito: **Estadísticas (Analytics)**.
  - Descripción: Recuento de clics en la publicidad de la app, clics en redes sociales y conteo de reproducciones de audio.

## 3. Compartición con Terceros
- Debes dejar explícitamente claro en todos los formularios de Google Play que **NO** compartes datos con terceros.
