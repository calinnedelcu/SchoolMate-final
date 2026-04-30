/**
 * One-shot backfill for the publicProfile mirror + custom claims that the
 * onUserDocWrite trigger maintains for newly-written users docs.
 *
 * Run this ONCE after deploying the trigger so existing users get their
 * publicProfile subdoc populated and Auth custom claims set.
 *
 * Usage:
 *   cd scripts
 *   # Place serviceAccountKey.json in this folder, then:
 *   node backfill_user_mirrors.js --dry      # report only, no writes
 *   node backfill_user_mirrors.js            # actually backfill
 *
 * Idempotent — safe to re-run; output is the same as the trigger's.
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
const auth = admin.auth();
const dryRun = process.argv.includes('--dry');

const PUBLIC_PROFILE_FIELDS = ['fullName', 'username', 'role', 'classId', 'status'];

function buildPublicProfile(data) {
    const out = {};
    for (const f of PUBLIC_PROFILE_FIELDS) {
        const v = data?.[f];
        if (v === undefined || v === null || v === '') continue;
        out[f] = v;
    }
    out.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    return out;
}

function buildClaims(data) {
    const role = String(data?.role || '').trim().toLowerCase();
    const classId = String(data?.classId || '').trim().toUpperCase();
    const claims = {};
    if (role) claims.role = role;
    if (classId) claims.classId = classId;
    return claims;
}

(async () => {
    console.log(`Mode: ${dryRun ? 'DRY RUN (no writes)' : 'LIVE (will mirror + set claims)'}\n`);

    const snap = await db.collection('users').get();
    console.log(`Found ${snap.size} user docs.\n`);

    let processed = 0;
    let claimsSet = 0;
    let claimsFailed = 0;
    const errors = [];

    for (const doc of snap.docs) {
        const data = doc.data() || {};
        const profile = buildPublicProfile(data);
        const claims = buildClaims(data);

        const summary = `${doc.id}: role=${claims.role || '-'} classId=${claims.classId || '-'} fullName="${profile.fullName || ''}"`;

        if (dryRun) {
            console.log('  [dry] ' + summary);
            processed++;
            continue;
        }

        try {
            await doc.ref
                .collection('publicProfile').doc('main')
                .set(profile, { merge: false });
            processed++;
        } catch (e) {
            errors.push({ uid: doc.id, stage: 'profile', error: String(e?.message || e) });
            console.error(`  ✗ ${doc.id} profile: ${e?.message || e}`);
            continue;
        }

        try {
            await auth.setCustomUserClaims(doc.id, claims);
            claimsSet++;
            console.log('  ✓ ' + summary);
        } catch (e) {
            // Doc has no Auth account (legacy or inconsistent). Profile is
            // mirrored anyway; claims simply do not apply to a missing user.
            claimsFailed++;
            console.warn(`  ! ${doc.id} claims skipped: ${e?.message || e}`);
        }
    }

    console.log('\n──────────────────────────────────────────');
    console.log(`Total scanned:  ${snap.size}`);
    console.log(`Profiles:       ${processed}${dryRun ? ' (would-be)' : ''}`);
    console.log(`Claims set:     ${claimsSet}`);
    console.log(`Claims failed:  ${claimsFailed} (no Auth account)`);
    if (errors.length) {
        console.log(`Errors:         ${errors.length} (see above)`);
    }
    console.log('Done.');
})()
    .catch((e) => {
        console.error('Fatal:', e);
        process.exit(1);
    });
