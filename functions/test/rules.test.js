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

describe('secretariatMessages write access', () => {
  const basePost = {
    recipientRole: 'student',
    recipientUid: '',
    studentUid: '',
    studentUsername: '',
    studentName: '',
    classId: '',
    recipientName: '',
    recipientUsername: '',
    message: 'Important launch-day announcement for students.',
    title: 'Launch announcement',
    category: 'announcement',
    audienceClassIds: ['__ALL__'],
    audienceLabel: 'Whole school',
    location: '',
    link: '',
    eventDate: null,
    eventEndDate: null,
    createdAt: new Date(),
    senderUid: 'admin1',
    senderName: 'Admin',
    senderRole: 'admin',
    broadcastId: 'test_broadcast',
    messageType: 'secretariatGlobal',
    source: 'secretariat',
    status: 'active',
  };

  test('admin can create a validated school post', async () => {
    const admin = testEnv.authenticatedContext('admin1').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/admin1').set({ role: 'admin' });
    });

    await assertSucceeds(
      admin.doc('secretariatMessages/post1').set(basePost),
    );
  });

  test('admin cannot create a post with unexpected fields', async () => {
    const admin = testEnv.authenticatedContext('admin1').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/admin1').set({ role: 'admin' });
    });

    await assertFails(
      admin.doc('secretariatMessages/post1').set({
        ...basePost,
        unsafeExtra: true,
      }),
    );
  });

  test('teacher can create only for their own class', async () => {
    const teacher = testEnv.authenticatedContext('teacher1').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc('users/teacher1')
        .set({ role: 'teacher', classId: '10A' });
    });

    await assertSucceeds(
      teacher.doc('secretariatMessages/post1').set({
        ...basePost,
        senderUid: 'teacher1',
        senderName: 'Teacher',
        senderRole: 'teacher',
        source: 'teacher',
        audienceClassIds: ['10A'],
        audienceLabel: 'Class 10A',
      }),
    );

    await assertFails(
      teacher.doc('secretariatMessages/post2').set({
        ...basePost,
        senderUid: 'teacher1',
        senderName: 'Teacher',
        senderRole: 'teacher',
        source: 'teacher',
        audienceClassIds: ['10B'],
        audienceLabel: 'Class 10B',
      }),
    );
  });
});

describe('secretariatMessages audience read access', () => {
  const postFor = (classIds) => ({
    recipientRole: 'student',
    recipientUid: '',
    studentUid: '',
    studentName: '',
    classId: '',
    message: 'Class-scoped announcement',
    title: 'Scoped',
    category: 'announcement',
    audienceClassIds: classIds,
    audienceLabel: classIds.join(', '),
    createdAt: new Date(),
    senderUid: 'admin1',
    senderName: 'Admin',
    senderRole: 'admin',
    broadcastId: `broadcast_${classIds.join('_')}`,
    messageType: 'secretariatGlobal',
    source: 'secretariat',
    status: 'active',
  });

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('users/student10a').set({ role: 'student', classId: '10A' });
      await db.doc('users/student10b').set({ role: 'student', classId: '10B' });
      await db.doc('users/teacher10a').set({ role: 'teacher', classId: '10A' });
      await db.doc('users/parent10a').set({
        role: 'parent',
        children: ['student10a'],
        childrenClassIds: ['10A'],
      });
      await db.doc('users/admin1').set({ role: 'admin' });
      await db.doc('secretariatMessages/all').set(postFor(['__ALL__']));
      await db.doc('secretariatMessages/only10a').set(postFor(['10A']));
      await db.doc('secretariatMessages/only10b').set(postFor(['10B']));
    });
  });

  test('student reads only whole-school and own-class broadcasts', async () => {
    const student = testEnv.authenticatedContext('student10a').firestore();
    await assertSucceeds(student.doc('secretariatMessages/all').get());
    await assertSucceeds(student.doc('secretariatMessages/only10a').get());
    await assertFails(student.doc('secretariatMessages/only10b').get());
  });

  test('student can query whole-school broadcasts by audience', async () => {
    const student = testEnv.authenticatedContext('student10a').firestore();
    const snap = await assertSucceeds(
      student.collection('secretariatMessages')
        .where('recipientRole', '==', 'student')
        .where('recipientUid', '==', '')
        .where('audienceClassIds', 'array-contains', '__ALL__')
        .get(),
    );
    expect(snap.docs.map((d) => d.id).sort()).toEqual(['all']);
  });

  test('student can query own-class broadcasts by audience', async () => {
    const student = testEnv.authenticatedContext('student10a').firestore();
    const snap = await assertSucceeds(
      student.collection('secretariatMessages')
        .where('recipientRole', '==', 'student')
        .where('recipientUid', '==', '')
        .where('audienceClassIds', 'array-contains', '10A')
        .get(),
    );
    expect(snap.docs.map((d) => d.id).sort()).toEqual(['only10a']);
  });

  test('teacher reads student broadcasts only for their class', async () => {
    const teacher = testEnv.authenticatedContext('teacher10a').firestore();
    await assertSucceeds(teacher.doc('secretariatMessages/all').get());
    await assertSucceeds(teacher.doc('secretariatMessages/only10a').get());
    await assertFails(teacher.doc('secretariatMessages/only10b').get());
  });

  test('parent reads student broadcasts only for child classes', async () => {
    const parent = testEnv.authenticatedContext('parent10a').firestore();
    await assertSucceeds(parent.doc('secretariatMessages/all').get());
    await assertSucceeds(parent.doc('secretariatMessages/only10a').get());
    await assertFails(parent.doc('secretariatMessages/only10b').get());
  });
});
