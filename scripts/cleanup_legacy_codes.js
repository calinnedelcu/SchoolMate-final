/**
 * One-shot cleanup for legacy plain-text reset/verify codes left in users docs
 * before the SHA-256 migration. New flows write only `*Hash` fields.
 *
 * Usage:
 *   cd scripts
 *   npm install firebase-admin    # if not already
 *   # Place serviceAccountKey.json in this folder, then:
 *   node cleanup_legacy_codes.js --dry        # report only, no writes
 *   node cleanup_legacy_codes.js              # actually delete
 */

const path = require('path');
const admin = require(path.join(__dirname, 'node_modules', 'firebase-admin'));

const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');

try {
    const serviceAccount = require(KEY_PATH);
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
} catch (e) {
    console.error('\n❌ serviceAccountKey.json lipsă.');
    console.error('   Descarcă din Firebase Console → Project Settings → Service Accounts');
    console.error('   Salvează ca: scripts/serviceAccountKey.json\n');
    process.exit(1);
}

const db = admin.firestore();
const dryRun = process.argv.includes('--dry');

const LEGACY_FIELDS = [
    'passwordResetCode',
    'verificationCode',
];

(async () => {
    console.log(`Mode: ${dryRun ? 'DRY RUN (no writes)' : 'LIVE (will delete)'}\n`);

    const snap = await db.collection('users').get();
    console.log(`Scanning ${snap.size} user docs...\n`);

    let toClean = 0;
    let cleaned = 0;
    let batch = db.batch();
    let pending = 0;
    const BATCH_LIMIT = 400;

    for (const doc of snap.docs) {
        const data = doc.data() || {};
        const present = LEGACY_FIELDS.filter((f) => data[f] !== undefined);
        if (present.length === 0) continue;

        toClean++;
        console.log(`  ${doc.id}: ${present.join(', ')}`);

        if (dryRun) continue;

        const updates = {};
        for (const f of present) updates[f] = admin.firestore.FieldValue.delete();
        batch.update(doc.ref, updates);
        pending++;

        if (pending >= BATCH_LIMIT) {
            await batch.commit();
            cleaned += pending;
            batch = db.batch();
            pending = 0;
        }
    }

    if (!dryRun && pending > 0) {
        await batch.commit();
        cleaned += pending;
    }

    console.log(`\nFound: ${toClean} user(s) with legacy plain code fields.`);
    if (!dryRun) console.log(`Cleaned: ${cleaned}`);
    console.log('Done.');
})()
    .catch((e) => {
        console.error('Error:', e);
        process.exit(1);
    });
