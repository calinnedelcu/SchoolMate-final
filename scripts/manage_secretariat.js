/**
 * Script pentru gestionarea conturilor de secretariat.
 *
 * Comenzi:
 *   node manage_secretariat.js create --username=ion.pop --fullName="Ion Pop" --password=Parola123
 *   node manage_secretariat.js patch  --username=secretariat --personalEmail=ion@gmail.com
 *   node manage_secretariat.js list
 *
 * Setup (o singură dată):
 *   1. Descarcă service account key din Firebase Console →
 *      Project Settings → Service Accounts → Generate new private key
 *   2. Salvează fișierul ca scripts/serviceAccountKey.json
 *   3. cd scripts && npm install firebase-admin
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
    console.error('   Descarcă din Firebase Console → Project Settings → Service Accounts → Generate new private key');
    console.error('   Salvează ca: scripts/serviceAccountKey.json\n');
    process.exit(1);
}

const db = admin.firestore();
const auth = admin.auth();

// ── helpers ──────────────────────────────────────────────────────────────────

function parseArgs(argv) {
    const args = {};
    for (const arg of argv.slice(3)) {
        const m = arg.match(/^--([^=]+)=(.+)$/);
        if (m) args[m[1]] = m[2];
    }
    return args;
}

function authEmail(username) {
    return `${username}@school.local`;
}

// ── comenzi ───────────────────────────────────────────────────────────────────

async function create({ username, fullName, password }) {
    if (!username || !fullName || !password) {
        console.error('❌ Parametri obligatorii: --username, --fullName, --password');
        process.exit(1);
    }
    if (password.length < 8) {
        console.error('❌ Parola trebuie să aibă cel puțin 8 caractere.');
        process.exit(1);
    }

    const email = authEmail(username);
    console.log(`\nCreez contul: ${email}`);

    // 1. Creează utilizatorul în Firebase Auth
    let userRecord;
    try {
        userRecord = await auth.createUser({
            email,
            password,
            displayName: fullName,
        });
        console.log(`✅ Firebase Auth: uid=${userRecord.uid}`);
    } catch (e) {
        if (e.code === 'auth/email-already-exists') {
            console.error(`❌ Utilizatorul ${email} există deja în Firebase Auth.`);
            console.error('   Folosește comanda "patch" pentru a actualiza un cont existent.');
        } else {
            console.error('❌ Eroare Auth:', e.message);
        }
        process.exit(1);
    }

    // 2. Creează documentul Firestore cu DOAR câmpurile esențiale.
    //    NU seta passwordChanged / emailVerified / onboardingComplete / personalEmail —
    //    onboarding-ul le va seta la primul login.
    await db.collection('users').doc(userRecord.uid).set({
        username,
        fullName,
        role: 'admin',
        status: 'active',
        authEmail: email,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Firestore: document creat');

    console.log('\n📋 Rezumat:');
    console.log(`   Email login : ${email}`);
    console.log(`   Parolă temp : ${password}`);
    console.log(`   UID         : ${userRecord.uid}`);
    console.log('\n⚠️  La primul login, secretariatul va trece prin onboarding:');
    console.log('   → setează email personal (pentru 2FA)');
    console.log('   → setează parolă nouă\n');
}

async function patch({ username, personalEmail }) {
    if (!username) {
        console.error('❌ Parametru obligatoriu: --username');
        process.exit(1);
    }

    const email = authEmail(username);
    console.log(`\nCaut contul: ${email}`);

    let userRecord;
    try {
        userRecord = await auth.getUserByEmail(email);
    } catch (e) {
        console.error(`❌ Utilizatorul ${email} nu există în Firebase Auth.`);
        process.exit(1);
    }

    const userRef = db.collection('users').doc(userRecord.uid);
    const snap = await userRef.get();
    if (!snap.exists) {
        console.error(`❌ Document Firestore lipsă pentru uid=${userRecord.uid}`);
        process.exit(1);
    }

    const data = snap.data();
    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

    if (personalEmail) {
        const emailLower = personalEmail.trim().toLowerCase();
        updates.personalEmail = personalEmail.trim();
        updates.personalEmailLower = emailLower;
        updates.emailVerified = true;
        console.log(`   personalEmail → ${personalEmail}`);
    }

    if (Object.keys(updates).length === 1) {
        console.log('   Nimic de actualizat. Adaugă --personalEmail=...');
        return;
    }

    await userRef.set(updates, { merge: true });
    console.log('✅ Firestore actualizat');

    const after = (await userRef.get()).data();
    console.log('\n📋 Stare actuală:');
    console.log(`   username         : ${after.username}`);
    console.log(`   personalEmail    : ${after.personalEmail || '(lipsă)'}`);
    console.log(`   emailVerified    : ${after.emailVerified ?? false}`);
    console.log(`   passwordChanged  : ${after.passwordChanged ?? false}`);
    console.log(`   onboardingComplete: ${after.onboardingComplete ?? false}\n`);
}

async function list() {
    console.log('\nConturi secretariat (role=admin):\n');
    const snap = await db.collection('users').where('role', '==', 'admin').get();
    if (snap.empty) {
        console.log('   (niciunul)\n');
        return;
    }

    const rows = snap.docs.map(d => {
        const data = d.data();
        return {
            username: data.username || '?',
            fullName: data.fullName || '?',
            personalEmail: data.personalEmail || '(lipsă)',
            emailVerified: data.emailVerified ?? false,
            onboardingComplete: data.onboardingComplete ?? false,
            uid: d.id,
        };
    });

    const col = (s, n) => String(s).padEnd(n);
    console.log(
        col('username', 20) +
        col('fullName', 20) +
        col('personalEmail', 30) +
        col('emailVerif', 12) +
        col('onboarded', 10) +
        'uid'
    );
    console.log('─'.repeat(100));
    for (const r of rows) {
        console.log(
            col(r.username, 20) +
            col(r.fullName, 20) +
            col(r.personalEmail, 30) +
            col(r.emailVerified, 12) +
            col(r.onboardingComplete, 10) +
            r.uid
        );
    }
    console.log();
}

async function security({ twoFactor, onboarding }) {
    if (twoFactor === undefined && onboarding === undefined) {
        const snap = await db.collection('app_settings').doc('security').get();
        const data = snap.exists ? snap.data() : {};
        console.log('\n📋 Setări securitate curente:');
        console.log(`   twoFactorEnabled  : ${data.twoFactorEnabled ?? false}`);
        console.log(`   onboardingEnabled : ${data.onboardingEnabled ?? true}\n`);
        return;
    }

    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (twoFactor !== undefined) {
        updates.twoFactorEnabled = twoFactor === 'true';
        console.log(`   twoFactorEnabled → ${updates.twoFactorEnabled}`);
    }
    if (onboarding !== undefined) {
        updates.onboardingEnabled = onboarding === 'true';
        console.log(`   onboardingEnabled → ${updates.onboardingEnabled}`);
    }

    await db.collection('app_settings').doc('security').set(updates, { merge: true });
    console.log('✅ Setări actualizate\n');
}

// ── entry point ───────────────────────────────────────────────────────────────

const command = process.argv[2];
const args = parseArgs(process.argv);

(async () => {
    try {
        if (command === 'create') await create(args);
        else if (command === 'patch') await patch(args);
        else if (command === 'list') await list();
        else if (command === 'security') await security(args);
        else {
            console.log('\nFolosire:');
            console.log('  node manage_secretariat.js create   --username=ion.pop --fullName="Ion Pop" --password=Parola123');
            console.log('  node manage_secretariat.js patch    --username=secretariat --personalEmail=ion@gmail.com');
            console.log('  node manage_secretariat.js list');
            console.log('  node manage_secretariat.js security --twoFactor=true|false --onboarding=true|false');
            console.log('  node manage_secretariat.js security   (fără argumente = afișează setările curente)\n');
        }
    } catch (e) {
        console.error('❌ Eroare:', e.message);
        process.exit(1);
    }
    process.exit(0);
})();
