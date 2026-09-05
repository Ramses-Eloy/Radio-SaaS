const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp();
const db = getFirestore();

async function testQuery() {
    const appId = 'fa';
    const snapshot = await db.collection('emisoras').where('appId', '==', appId).get();
    let maxSuffix = 0;
    snapshot.forEach(doc => {
        console.log("Found doc:", doc.id);
        const parts = doc.id.split('_');
        if (parts.length > 1) {
            const suffix = parseInt(parts[parts.length - 1], 10);
            if (!isNaN(suffix) && suffix > maxSuffix) {
                maxSuffix = suffix;
            }
        }
    });
    const newId = `${appId}_${maxSuffix + 1}`;
    console.log("New ID would be:", newId);
}

testQuery().catch(console.error);
