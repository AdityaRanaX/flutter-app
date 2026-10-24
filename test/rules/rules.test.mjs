// Firestore Security Rules runtime tests for EduLens.
//
// These run real read and write requests against the real rules engine in
// the Firebase Emulator Suite. That is the difference between this file
// and everything under `test/*.dart`: the Dart tests use in-memory fakes
// and execute no rules at all, so they can only show how the app responds
// to a denial, never whether Firestore would actually deny it.
//
// Run with:   cd test/rules && npm install && npm test
//
// The emulator is seeded through `withSecurityRulesDisabled`, so the
// fixtures themselves are not an authorization claim; only the assertions
// below are.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test, { after } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rulesPath = path.resolve(here, '..', '..', 'firestore.rules');

const SCHOOL_A = 'sch-a';
const SCHOOL_B = 'sch-b';

const testEnv = await initializeTestEnvironment({
  projectId: 'edulens-rules-test',
  firestore: {
    rules: readFileSync(rulesPath, 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

await testEnv.clearFirestore();
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();

  const users = {
    'dist-1': { role: 'districtAdmin', schoolId: null },
    'admin-a': { role: 'schoolAdmin', schoolId: SCHOOL_A },
    'admin-b': { role: 'schoolAdmin', schoolId: SCHOOL_B },
    'teach-a': { role: 'teacher', schoolId: SCHOOL_A },
    'teach-b': { role: 'teacher', schoolId: SCHOOL_B },
    // Provisioned student: a staff member set schoolId, so exams resolve.
    'stu-a': { role: 'student', schoolId: SCHOOL_A },
    'stu-a2': { role: 'student', schoolId: SCHOOL_A },
    // Self-registered student: the users create rule forbids choosing a
    // schoolId, so this is the shape a student has before provisioning.
    'stu-nos': { role: 'student', schoolId: '' },
  };
  for (const [uid, data] of Object.entries(users)) {
    await setDoc(doc(db, 'users', uid), {
      uid,
      name: uid,
      email: `${uid}@edulens.test`,
      ...data,
    });
  }

  for (const id of [SCHOOL_A, SCHOOL_B]) {
    await setDoc(doc(db, 'schools', id), {
      schoolId: id,
      schoolName: `School ${id}`,
      location: 'Zone 1',
    });
  }

  for (const [id, schoolId] of [
    ['stu-a', SCHOOL_A],
    ['stu-a2', SCHOOL_A],
    ['stu-nos', SCHOOL_A],
    ['stu-b', SCHOOL_B],
  ]) {
    await setDoc(doc(db, 'students', id), {
      studentId: id,
      name: id,
      schoolId,
      className: 'Class 10',
      section: 'A',
    });
  }

  for (const [id, studentId, schoolId] of [
    ['att-a1', 'stu-a', SCHOOL_A],
    ['att-a2', 'stu-a2', SCHOOL_A],
    ['att-b1', 'stu-b', SCHOOL_B],
  ]) {
    await setDoc(doc(db, 'attendance', id), {
      attendanceId: id,
      studentId,
      schoolId,
      teacherId: schoolId === SCHOOL_A ? 'teach-a' : 'teach-b',
      date: '2026-10-24',
      status: 'Present',
    });
  }

  for (const [id, studentId, schoolId] of [
    ['fee-a1', 'stu-a', SCHOOL_A],
    ['fee-a2', 'stu-a2', SCHOOL_A],
    ['fee-b1', 'stu-b', SCHOOL_B],
  ]) {
    await setDoc(doc(db, 'fees', id), {
      feeId: id,
      studentId,
      schoolId,
      totalDue: 1000,
      paidAmount: 250,
      status: 'Partial',
      updatedAt: '2026-10-01',
    });
  }

  for (const [id, schoolId, createdBy] of [
    ['exam-a1', SCHOOL_A, 'teach-a'],
    ['exam-b1', SCHOOL_B, 'teach-b'],
  ]) {
    await setDoc(doc(db, 'exams', id), {
      examId: id,
      schoolId,
      className: 'Class 10',
      subject: 'Physics',
      date: '2026-11-02',
      startTime: '09:00',
      endTime: '11:00',
      createdBy,
    });
  }
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

after(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------- unauthenticated

test('unauthenticated access is refused everywhere', async () => {
  const db = anon();
  await assertFails(getDoc(doc(db, 'schools', SCHOOL_A)));
  await assertFails(getDoc(doc(db, 'students', 'stu-a')));
  await assertFails(getDoc(doc(db, 'attendance', 'att-a1')));
  await assertFails(getDoc(doc(db, 'fees', 'fee-a1')));
  await assertFails(getDoc(doc(db, 'exams', 'exam-a1')));
});

// -------------------------------------------------------------- district

test('a district admin reads across schools', async () => {
  const db = as('dist-1');
  await assertSucceeds(getDoc(doc(db, 'schools', SCHOOL_A)));
  await assertSucceeds(getDoc(doc(db, 'schools', SCHOOL_B)));
  await assertSucceeds(getDoc(doc(db, 'students', 'stu-b')));
  await assertSucceeds(getDoc(doc(db, 'attendance', 'att-b1')));
  await assertSucceeds(getDoc(doc(db, 'fees', 'fee-b1')));
});

// ---------------------------------------------------------- school admin

test('a school admin reads their own school and not another', async () => {
  const db = as('admin-a');
  await assertSucceeds(getDoc(doc(db, 'schools', SCHOOL_A)));
  await assertSucceeds(getDoc(doc(db, 'students', 'stu-a')));
  await assertSucceeds(getDoc(doc(db, 'fees', 'fee-a1')));

  await assertFails(getDoc(doc(db, 'schools', SCHOOL_B)));
  await assertFails(getDoc(doc(db, 'students', 'stu-b')));
  await assertFails(getDoc(doc(db, 'fees', 'fee-b1')));
});

test('a school admin updates a fee in their school', async () => {
  const db = as('admin-a');
  await assertSucceeds(
    updateDoc(doc(db, 'fees', 'fee-a1'), {
      status: 'Paid',
      paidAmount: 1000,
      remarks: 'Settled',
    }),
  );
});

test('a school admin cannot move a record to another school', async () => {
  const db = as('admin-a');
  // Ownership transfer through an otherwise ordinary update.
  await assertFails(
    updateDoc(doc(db, 'fees', 'fee-a1'), { schoolId: SCHOOL_B }),
  );
  await assertFails(
    updateDoc(doc(db, 'students', 'stu-a'), { schoolId: SCHOOL_B }),
  );
});

test('a school admin cannot write into another school', async () => {
  const db = as('admin-a');
  await assertFails(
    setDoc(doc(db, 'students', 'intruder'), {
      studentId: 'intruder',
      name: 'Intruder',
      schoolId: SCHOOL_B,
      className: 'Class 10',
      section: 'A',
    }),
  );
});

// --------------------------------------------------------------- teacher

test('a teacher records attendance for their own school', async () => {
  const db = as('teach-a');
  await assertSucceeds(
    setDoc(doc(db, 'attendance', 'att-new-a'), {
      attendanceId: 'att-new-a',
      studentId: 'stu-a',
      schoolId: SCHOOL_A,
      teacherId: 'teach-a',
      date: '2026-10-25',
      status: 'Present',
    }),
  );
});

test('a teacher cannot record attendance for another school', async () => {
  const db = as('teach-a');
  await assertFails(
    setDoc(doc(db, 'attendance', 'att-new-b'), {
      attendanceId: 'att-new-b',
      studentId: 'stu-b',
      schoolId: SCHOOL_B,
      teacherId: 'teach-a',
      date: '2026-10-25',
      status: 'Present',
    }),
  );
});

test('a teacher cannot attribute attendance to another teacher', async () => {
  const db = as('teach-a');
  await assertFails(
    setDoc(doc(db, 'attendance', 'att-spoof'), {
      attendanceId: 'att-spoof',
      studentId: 'stu-a',
      schoolId: SCHOOL_A,
      teacherId: 'teach-b',
      date: '2026-10-25',
      status: 'Present',
    }),
  );
});

test('a teacher schedules an exam they author', async () => {
  const db = as('teach-a');
  await assertSucceeds(
    setDoc(doc(db, 'exams', 'exam-new-a'), {
      examId: 'exam-new-a',
      schoolId: SCHOOL_A,
      className: 'Class 10',
      subject: 'Chemistry',
      date: '2026-11-05',
      startTime: '09:00',
      endTime: '11:00',
      createdBy: 'teach-a',
    }),
  );
});

test('a teacher cannot author an exam as someone else', async () => {
  const db = as('teach-a');
  await assertFails(
    setDoc(doc(db, 'exams', 'exam-spoof'), {
      examId: 'exam-spoof',
      schoolId: SCHOOL_A,
      className: 'Class 10',
      subject: 'Chemistry',
      date: '2026-11-05',
      startTime: '09:00',
      endTime: '11:00',
      createdBy: 'teach-b',
    }),
  );
});

// --------------------------------------------------------------- student

test('a student reads their own attendance and fee record', async () => {
  const db = as('stu-a');
  await assertSucceeds(getDoc(doc(db, 'attendance', 'att-a1')));
  await assertSucceeds(getDoc(doc(db, 'fees', 'fee-a1')));
  await assertSucceeds(getDoc(doc(db, 'students', 'stu-a')));
});

test('a student queries their own attendance by studentId', async () => {
  // The shape the Student Dashboard actually issues.
  const db = as('stu-a');
  await assertSucceeds(
    getDocs(
      query(collection(db, 'attendance'), where('studentId', '==', 'stu-a')),
    ),
  );
});

test('a student cannot read a classmate attendance record', async () => {
  const db = as('stu-a');
  await assertFails(getDoc(doc(db, 'attendance', 'att-a2')));
});

test('a student cannot read a classmate fee record', async () => {
  const db = as('stu-a');
  await assertFails(getDoc(doc(db, 'fees', 'fee-a2')));
});

test('a student cannot read a classmate student record', async () => {
  const db = as('stu-a');
  await assertFails(getDoc(doc(db, 'students', 'stu-a2')));
});

test('a student cannot list every record in their school', async () => {
  const db = as('stu-a');
  await assertFails(
    getDocs(
      query(collection(db, 'fees'), where('schoolId', '==', SCHOOL_A)),
    ),
  );
  await assertFails(
    getDocs(
      query(collection(db, 'attendance'), where('schoolId', '==', SCHOOL_A)),
    ),
  );
});

test('a student cannot reach another school at all', async () => {
  const db = as('stu-a');
  await assertFails(getDoc(doc(db, 'attendance', 'att-b1')));
  await assertFails(getDoc(doc(db, 'fees', 'fee-b1')));
  await assertFails(getDoc(doc(db, 'exams', 'exam-b1')));
});

test('a provisioned student reads their own school exams', async () => {
  // Confirms the Day 11 finding from the other side: with schoolId set on
  // the user profile, the exam read resolves.
  const db = as('stu-a');
  await assertSucceeds(getDoc(doc(db, 'exams', 'exam-a1')));
});

test('a student without a schoolId is denied exams', async () => {
  // The Day 11 provisioning dependency, verified at runtime rather than
  // inferred: self-registration cannot set schoolId, so exams stay denied
  // until staff provision the profile.
  const db = as('stu-nos');
  await assertSucceeds(getDoc(doc(db, 'students', 'stu-nos')));
  await assertFails(getDoc(doc(db, 'exams', 'exam-a1')));
});

test('a student cannot write attendance, fees or exams', async () => {
  const db = as('stu-a');
  await assertFails(
    updateDoc(doc(db, 'attendance', 'att-a1'), { status: 'Absent' }),
  );
  await assertFails(
    setDoc(doc(db, 'attendance', 'att-self'), {
      attendanceId: 'att-self',
      studentId: 'stu-a',
      schoolId: SCHOOL_A,
      teacherId: 'stu-a',
      date: '2026-10-26',
      status: 'Present',
    }),
  );
  await assertFails(
    updateDoc(doc(db, 'fees', 'fee-a1'), { status: 'Paid', paidAmount: 1000 }),
  );
  await assertFails(
    setDoc(doc(db, 'exams', 'exam-self'), {
      examId: 'exam-self',
      schoolId: SCHOOL_A,
      className: 'Class 10',
      subject: 'Free period',
      date: '2026-11-09',
      startTime: '09:00',
      endTime: '11:00',
      createdBy: 'stu-a',
    }),
  );
});

test('a student cannot promote themselves', async () => {
  const db = as('stu-a');
  await assertFails(
    updateDoc(doc(db, 'users', 'stu-a'), { role: 'districtAdmin' }),
  );
  await assertFails(
    updateDoc(doc(db, 'users', 'stu-a'), { schoolId: SCHOOL_B }),
  );
});

test('a student cannot read another user profile', async () => {
  const db = as('stu-a');
  await assertFails(getDoc(doc(db, 'users', 'stu-a2')));
  await assertSucceeds(getDoc(doc(db, 'users', 'stu-a')));
});
