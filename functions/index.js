const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Inicializar la aplicación de Firebase Admin
initializeApp();

exports.updateUserCredentials = functions.https.onCall(async (data, context) => {
    // Verificar que el usuario que llama a la función esté autenticado
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'La función debe ser llamada mientras estás autenticado.'
        );
    }

    // Verificar que el usuario que llama sea el Super Admin
    if (context.auth.token.email !== 'rsarsanedasg@gmail.com') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Solo el Super Administrador puede realizar esta acción.'
        );
    }

    const currentEmail = data.currentEmail;
    const newEmail = data.newEmail;
    const newPassword = data.newPassword;

    if (!currentEmail) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Se requiere el correo actual (currentEmail) para encontrar al usuario.'
        );
    }

    try {
        let userRecord;

        // Paso 1: Intentar encontrar al usuario por su correo actual
        try {
            userRecord = await getAuth().getUserByEmail(currentEmail);
        } catch (err) {
            if (err.code === 'auth/user-not-found') {
                // El usuario no existe en Auth, intentar crearlo
                const emailToCreate = (newEmail && newEmail.trim() !== '') ? newEmail.trim().toLowerCase() : currentEmail;
                const passwordToCreate = (newPassword && newPassword.trim() !== '') ? newPassword.trim() : 'TempPass123!';
                
                try {
                    userRecord = await getAuth().createUser({
                        email: emailToCreate,
                        password: passwordToCreate,
                    });
                } catch (createErr) {
                    if (createErr.code === 'auth/email-already-exists') {
                        // El email existe pero bajo otra cuenta, encontrarlo
                        userRecord = await getAuth().getUserByEmail(emailToCreate);
                    } else {
                        throw createErr;
                    }
                }
            } else {
                throw err;
            }
        }

        // Paso 2: Si el usuario ya existía, actualizar sus datos
        const updates = {};
        // Solo enviar newEmail si realmente cambió
        if (newEmail && newEmail.trim() !== '' && newEmail.trim().toLowerCase() !== currentEmail.trim().toLowerCase()) {
            updates.email = newEmail.trim().toLowerCase();
        }
        if (newPassword && newPassword.trim() !== '') {
            updates.password = newPassword.trim();
        }

        if (Object.keys(updates).length > 0) {
            await getAuth().updateUser(userRecord.uid, updates);
        }

        // Si el correo cambió, actualizar todas las referencias en Firestore
        if (newEmail && newEmail.trim() !== '') {
            const normalizedEmail = newEmail.trim().toLowerCase();
            const db = getFirestore();
            const appId = data.appId;
            
            if (appId) {
                const batch = db.batch();
                
                // Marcas
                batch.update(db.collection('marcas').doc(appId), { ownerEmail: normalizedEmail });

                // Emisoras
                const emisoras = await db.collection('emisoras').where('appId', '==', appId).get();
                emisoras.forEach(doc => {
                    batch.update(doc.ref, { ownerEmail: normalizedEmail });
                });

                // Streamings
                const streamings = await db.collection('streamings').where('appId', '==', appId).get();
                streamings.forEach(doc => {
                    const data = doc.data();
                    if (data.ownerEmail) {
                        batch.update(doc.ref, { ownerEmail: normalizedEmail });
                    }
                });

                // Programacion
                const programacion = await db.collection('programacion').where('appId', '==', appId).get();
                programacion.forEach(doc => {
                    const data = doc.data();
                    if (data.ownerEmail) {
                        batch.update(doc.ref, { ownerEmail: normalizedEmail });
                    }
                });

                await batch.commit();
            }
        }

        return { success: true, message: 'Credenciales actualizadas correctamente' };
    } catch (error) {
        console.error('Error actualizando credenciales:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

exports.createBrand = functions.https.onCall(async (data, context) => {
    // Verificar que el usuario esté autenticado
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debe estar autenticado.');
    }

    // Verificar que sea Super Admin
    if (context.auth.token.email !== 'rsarsanedasg@gmail.com' && context.auth.token.email !== 'ramseseloy11@gmail.com') {
        throw new functions.https.HttpsError('permission-denied', 'Solo Super Admin.');
    }

    const { appId, nombreGrupo, ownerEmail, password, features } = data;
    
    if (!appId || !nombreGrupo || !ownerEmail || !password) {
        throw new functions.https.HttpsError('invalid-argument', 'Faltan campos requeridos.');
    }

    const normalizedAppId = appId.trim().toLowerCase();
    const normalizedEmail = ownerEmail.trim().toLowerCase();
    const db = getFirestore();

    // 1. Validar que el appId no exista
    const existing = await db.collection('marcas').doc(normalizedAppId).get();
    if (existing.exists) {
        throw new functions.https.HttpsError('already-exists', `La marca ${normalizedAppId} ya existe.`);
    }

    try {
        // 2. Crear usuario en Auth (falla si el email ya está en uso)
        let userRecord;
        try {
            userRecord = await getAuth().createUser({
                email: normalizedEmail,
                password: password,
            });
        } catch (authErr) {
            if (authErr.code === 'auth/email-already-exists') {
                // No es un error fatal si el cliente ya tenía cuenta, pero idealmente usamos esa cuenta
                userRecord = await getAuth().getUserByEmail(normalizedEmail);
            } else {
                throw authErr;
            }
        }

        const batch = db.batch();

        // 3. Crear documento en `marcas`
        const marcaRef = db.collection('marcas').doc(normalizedAppId);
        batch.set(marcaRef, {
            appId: normalizedAppId,
            nombre_grupo: nombreGrupo,
            ownerEmail: normalizedEmail,
            logo_url: '',
            color_hex: '#205CC6',
            splash_url: '',
            banner_home_url: '',
            splash_enabled: true,
            splash_duration_sec: 5,
            radio_label: 'Radio',
            tv_label: 'Video Live',
            schedule_label: 'Programación',
            features: features,
            created_at: new Date(),
            active: true,
        });

        // 4. Crear emisora inicial
        const emisoraRef = db.collection('emisoras').doc(`${normalizedAppId}_1`);
        batch.set(emisoraRef, {
            appId: normalizedAppId,
            ownerEmail: normalizedEmail,
            nombre: nombreGrupo,
            slogan: 'La mejor música',
            logo_url: '',
            color_hex: '#205CC6',
            color_secundario_hex: '#35ACE5',
            mostrar_programacion: features.enableSchedule || false,
            isVideo: false,
            url_audio: '',
            url_video: '',
            telefono_cabina: '',
            social_whatsapp: '',
            social_facebook: '',
            social_instagram: '',
            social_x: '',
            social_tiktok: '',
            youtube_url: '',
        });

        await batch.commit();

        return { success: true, message: 'Marca creada exitosamente' };
    } catch (err) {
        console.error('Error creando marca:', err);
        throw new functions.https.HttpsError('internal', err.message);
    }
});

exports.createStation = functions.https.onCall(async (data, context) => {
    // Verificar autenticación y Super Admin
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Debe estar autenticado.');
    if (context.auth.token.email !== 'rsarsanedasg@gmail.com' && context.auth.token.email !== 'ramseseloy11@gmail.com') {
        throw new functions.https.HttpsError('permission-denied', 'Solo Super Admin.');
    }

    const db = getFirestore();
    
    // Find next sequential ID
    const snapshot = await db.collection('emisoras').where('appId', '==', data.appId).get();
    let maxSuffix = 0;
    snapshot.forEach(doc => {
        const parts = doc.id.split('_');
        if (parts.length > 1) {
            const suffix = parseInt(parts[parts.length - 1], 10);
            if (!isNaN(suffix) && suffix > maxSuffix) {
                maxSuffix = suffix;
            }
        }
    });
    const newId = `${data.appId}_${maxSuffix + 1}`;
    const docRef = db.collection('emisoras').doc(newId);
    await docRef.set({
        appId: data.appId,
        ownerEmail: data.ownerEmail,
        nombre: data.nombre,
        slogan: '',
        logo_url: data.logoUrl || '',
        color_hex: data.colorHex || '#205CC6',
        color_secundario_hex: data.colorSecundarioHex || '#35ACE5',
        mostrar_programacion: data.mostrarProgramacion || false,
        isVideo: false,
        url_audio: data.urlAudio || '',
        url_video: '',
        telefono_cabina: data.telefonoCabina || '',
        social_whatsapp: data.socialWhatsapp || '',
        social_facebook: data.socialFacebook || '',
        social_instagram: data.socialInstagram || '',
        social_x: data.socialX || '',
        social_tiktok: '',
        youtube_url: '',
    });

    return { success: true, docId: docRef.id };
});

exports.createStreamingChannel = functions.https.onCall(async (data, context) => {
    // Verificar autenticación y Super Admin
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Debe estar autenticado.');
    if (context.auth.token.email !== 'rsarsanedasg@gmail.com' && context.auth.token.email !== 'ramseseloy11@gmail.com') {
        throw new functions.https.HttpsError('permission-denied', 'Solo Super Admin.');
    }

    const db = getFirestore();
    
    // Find next sequential ID
    const snapshot = await db.collection('streamings').where('appId', '==', data.appId).get();
    let maxSuffix = 0;
    snapshot.forEach(doc => {
        const parts = doc.id.split('_');
        if (parts.length > 1) {
            const suffix = parseInt(parts[parts.length - 1], 10);
            if (!isNaN(suffix) && suffix > maxSuffix) {
                maxSuffix = suffix;
            }
        }
    });
    const newId = `${data.appId}_${maxSuffix + 1}`;
    const docRef = db.collection('streamings').doc(newId);
    await docRef.set({
        appId: data.appId,
        ownerEmail: data.ownerEmail,
        nombre: data.nombre,
        url_video: data.urlVideo || '',
        logo_url: data.logoUrl || '',
        color_hex: data.colorHex || '#10B981',
        color_secundario_hex: data.colorSecundarioHex || '#059669',
        mostrar_programacion: data.mostrarProgramacion || false,
    });

    return { success: true, docId: docRef.id };
});

/**
 * Fetches the latest stream video IDs from a YouTube channel's /streams page.
 * Works with both UC... channel IDs and @handle usernames.
 * Parses the structured ytInitialData JSON to extract only the channel's own
 * stream videos (not recommended/ad videos).
 * Returns an array of video URLs in chronological order (most recent first).
 */
async function fetchYouTubeStreamVideoUrls(channelIdentifier) {
    // Build the URL: if it starts with UC it's a channel ID, otherwise treat as handle
    let pageUrl;
    if (channelIdentifier.startsWith('UC') && channelIdentifier.length === 24) {
        pageUrl = `https://www.youtube.com/channel/${channelIdentifier}/streams`;
    } else if (channelIdentifier.startsWith('@')) {
        pageUrl = `https://www.youtube.com/${channelIdentifier}/streams`;
    } else {
        pageUrl = `https://www.youtube.com/@${channelIdentifier}/streams`;
    }

    const response = await fetch(pageUrl, {
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9'
        }
    });
    const html = await response.text();

    // Parse the structured ytInitialData JSON embedded in the page
    const jsonMatch = html.match(/var ytInitialData = ({.*?});/);
    if (jsonMatch) {
        try {
            const data = JSON.parse(jsonMatch[1]);
            const tabs = data?.contents?.twoColumnBrowseResultsRenderer?.tabs || [];
            
            for (const tab of tabs) {
                const tabRenderer = tab?.tabRenderer;
                if (tabRenderer?.selected) {
                    const items = tabRenderer?.content?.richGridRenderer?.contents || [];
                    const videoUrls = [];
                    
                    for (const item of items) {
                        // YouTube uses lockupViewModel for stream items
                        const contentId = item?.richItemRenderer?.content?.lockupViewModel?.contentId;
                        if (contentId) {
                            videoUrls.push(`https://www.youtube.com/watch?v=${contentId}`);
                        }
                    }
                    
                    if (videoUrls.length > 0) {
                        console.log(`Parsed ${videoUrls.length} stream videos from ytInitialData for ${channelIdentifier}`);
                        return videoUrls;
                    }
                }
            }
        } catch (parseError) {
            console.error(`Error parsing ytInitialData JSON:`, parseError);
        }
    }

    // Fallback: use regex but try to be more targeted
    console.log(`Falling back to regex extraction for ${channelIdentifier}`);
    const regex = /"contentId":"([a-zA-Z0-9_-]{11})"/g;
    const videoUrls = [];
    const seen = new Set();
    let match;
    while ((match = regex.exec(html)) !== null) {
        if (!seen.has(match[1])) {
            seen.add(match[1]);
            videoUrls.push(`https://www.youtube.com/watch?v=${match[1]}`);
        }
    }
    return videoUrls;
}

exports.syncYouTubeStreams = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
    const db = getFirestore();
    
    try {
        // Obtenemos todos los streamings que tengan youtube_auto_sync activado
        const streamingsSnapshot = await db.collection('streamings')
            .where('youtube_auto_sync', '==', true)
            .get();
            
        const channelsToUpdate = {};
        
        // Agrupamos por channelId para no hacer peticiones duplicadas
        streamingsSnapshot.forEach(doc => {
            const data = doc.data();
            const channelId = data.youtube_channel_id;
            if (channelId && channelId.trim() !== '') {
                const key = channelId.trim();
                if (!channelsToUpdate[key]) {
                    channelsToUpdate[key] = [];
                }
                channelsToUpdate[key].push({ ref: doc.ref, syncType: data.youtube_sync_type || 'principal', currentUrl: data.url_video || '' });
            }
        });

        const batch = db.batch();
        let updated = 0;

        for (const channelId of Object.keys(channelsToUpdate)) {
            try {
                const videoUrls = await fetchYouTubeStreamVideoUrls(channelId);

                if (videoUrls.length > 0) {
                    const principalUrl = videoUrls[0];
                    const retransmisionUrl = videoUrls.length > 1 ? videoUrls[1] : principalUrl;

                    for (const streaming of channelsToUpdate[channelId]) {
                        const newUrl = streaming.syncType === 'retransmision' ? retransmisionUrl : principalUrl;
                        // Solo escribir si cambió: evita escrituras y relecturas en los oyentes.
                        if (newUrl === streaming.currentUrl) continue;
                        batch.update(streaming.ref, { url_video: newUrl });
                        updated++;
                    }
                } else {
                    console.log(`No stream videos found for channel: ${channelId}`);
                }
            } catch (fetchError) {
                console.error(`Error fetching YouTube streams for channel ${channelId}:`, fetchError);
            }
        }

        if (updated > 0) {
            await batch.commit();
            console.log(`YouTube streams synced successfully. Updated ${updated} channels.`);
        }

    } catch (error) {
        console.error('Error syncing YouTube streams:', error);
    }
    return null;
});

exports.sendAvanceInformativoPush = functions.firestore
    .document('marcas/{appId}')
    .onUpdate(async (change, context) => {
        const appId = context.params.appId;
        const beforeData = change.before.data();
        const afterData = change.after.data();

        const beforeAlertId = beforeData.alerta_global?.id_alerta;
        const afterAlertId = afterData.alerta_global?.id_alerta;

        // If a new alert was triggered
        if (afterAlertId && afterAlertId !== beforeAlertId) {
            const mensaje = afterData.alerta_global?.mensaje || 'Nuevo avance informativo';
            const topic = `brand_${appId}`;

            const payload = {
                notification: {
                    title: 'Avance Informativo',
                    body: mensaje
                },
                topic: topic
            };

            try {
                await getMessaging().send(payload);
                console.log(`Successfully sent push notification to topic: ${topic}`);
            } catch (error) {
                console.error(`Error sending push notification to topic ${topic}:`, error);
            }
        }
        return null;
    });

exports.resolveYouTubeChannelId = functions.firestore
    .document('streamings/{streamingId}')
    .onWrite(async (change, context) => {
        // Si el documento fue eliminado
        if (!change.after.exists) return null;

        const newData = change.after.data();
        const oldData = change.before.exists ? change.before.data() : {};

        const newIdOrUrl = newData.youtube_channel_id || '';
        const oldIdOrUrl = oldData.youtube_channel_id || '';

        // Si no cambió o está vacío, no hacer nada
        if (newIdOrUrl === oldIdOrUrl || newIdOrUrl.trim() === '') return null;

        let channelStr = newIdOrUrl.trim();

        // Si ya es un ID de canal válido (UC...) o un handle limpio (@...), no hacer nada
        if ((channelStr.startsWith('UC') && channelStr.length === 24) || 
            (channelStr.startsWith('@') && !channelStr.includes('/'))) {
            return null;
        }

        console.log(`Normalizando canal de YouTube: ${channelStr}`);
        
        // Extraer handle o channel ID de URLs de YouTube
        // Ejemplos:
        //   https://www.youtube.com/@radioreformaseoye1027
        //   https://www.youtube.com/@radioreformaseoye1027/streams
        //   https://www.youtube.com/channel/UCxxxxxx
        //   https://youtube.com/@MiCanal
        let normalized = null;

        // Intentar extraer @handle de la URL
        const handleMatch = channelStr.match(/@([a-zA-Z0-9._-]+)/);
        if (handleMatch) {
            normalized = `@${handleMatch[1]}`;
        }

        // Intentar extraer UC... channel ID de la URL
        if (!normalized) {
            const ucMatch = channelStr.match(/(UC[a-zA-Z0-9_-]{22})/);
            if (ucMatch) {
                normalized = ucMatch[1];
            }
        }

        // Si no pudimos extraer nada reconocible, asumimos que es un handle sin @
        if (!normalized && !channelStr.includes(' ') && !channelStr.includes('/')) {
            normalized = `@${channelStr}`;
        }

        if (normalized && normalized !== channelStr) {
            console.log(`Normalizado ${channelStr} a ${normalized}`);
            return change.after.ref.update({ youtube_channel_id: normalized });
        }

        return null;
    });
