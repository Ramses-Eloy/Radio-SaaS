const { initializeApp, cert } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');

initializeApp({
  storageBucket: 'radio-saas-platform.firebasestorage.app'
});

async function configureCors() {
  const bucket = getStorage().bucket();
  await bucket.setCorsConfiguration([
    {
      origin: ['*'],
      method: ['GET', 'PUT', "POST", "DELETE", "OPTIONS"],
      maxAgeSeconds: 3600,
      responseHeader: ['*']
    }
  ]);
  console.log('CORS configured successfully.');
}

configureCors().catch(console.error);
