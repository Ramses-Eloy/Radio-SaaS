const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

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
            radio_label: 'En Vivo',
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
