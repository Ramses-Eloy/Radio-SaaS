const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp();
const db = getFirestore();

async function fixDocument() {
  const oldId = 'PYI0ty4fo1fczEk38fl8';
  const newId = 'fa_2';
  
  const docRef = db.collection('emisoras').doc(oldId);
  const doc = await docRef.get();
  
  if (doc.exists) {
    await db.collection('emisoras').doc(newId).set(doc.data());
    await docRef.delete();
    console.log('Fixed emisora ID successfully');
  } else {
    console.log('Document not found or already deleted');
  }
}

fixDocument().catch(console.error);
