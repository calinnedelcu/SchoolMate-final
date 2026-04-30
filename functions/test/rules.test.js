const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'schoolmate-test',
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('users/{userId} read access', () => {
  test('owner can read own doc', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc('users/alice')
        .set({ role: 'student', personalEmail: 'a@x.com' });
    });
    await assertSucceeds(alice.doc('users/alice').get());
  });

  test('non-admin cannot read another user doc', async () => {
    const bob = testEnv.authenticatedContext('bob').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc('users/alice')
        .set({ role: 'student', personalEmail: 'a@x.com' });
      await ctx
        .firestore()
        .doc('users/bob')
        .set({ role: 'student', personalEmail: 'b@x.com' });
    });
    await assertFails(bob.doc('users/alice').get());
  });

  test('admin can read any user doc', async () => {
    const admin = testEnv.authenticatedContext('admin1').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/admin1').set({ role: 'admin' });
      await ctx.firestore().doc('users/alice').set({ role: 'student' });
    });
    await assertSucceeds(admin.doc('users/alice').get());
  });

  test('publicProfile is readable by other authenticated users', async () => {
    const bob = testEnv.authenticatedContext('bob').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc('users/alice/publicProfile/info')
        .set({ name: 'Alice' });
    });
    await assertSucceeds(bob.doc('users/alice/publicProfile/info').get());
  });

  test('unauthenticated cannot read user doc', async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/alice').set({ role: 'student' });
    });
    await assertFails(anon.doc('users/alice').get());
  });
});
