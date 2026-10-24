// Measures write-to-visible latency for an authorized reader.
//
// SCOPE, because the number is easy to misread: this runs against the
// Firebase Emulator Suite on localhost. It measures the application's
// write -> authorized read path through the real rules engine, and it
// excludes everything the production path adds — WAN latency, real
// Firebase auth, multi-region replication and contention.
//
// It is therefore evidence that the path works and that authorization
// does not delay it. It is NOT evidence for the PRD V2 target, which is
// about authorized dashboards in production.
//
// Run with:   cd test/rules && npm run freshness
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rulesPath = path.resolve(here, '..', '..', 'firestore.rules');

const SCHOOL = 'sch-a';
const SAMPLES = Number(process.env.SAMPLES ?? 20);
const TARGET_MS = 5000;

const testEnv = await initializeTestEnvironment({
  projectId: 'edulens-freshness',
  firestore: {
    rules: readFileSync(rulesPath, 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

await testEnv.clearFirestore();
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  for (const [uid, role] of [
    ['teach-a', 'teacher'],
    ['admin-a', 'schoolAdmin'],
  ]) {
    await setDoc(doc(db, 'users', uid), {
      uid,
      name: uid,
      email: `${uid}@edulens.test`,
      role,
      schoolId: SCHOOL,
    });
  }
});

const writer = testEnv.authenticatedContext('teach-a').firestore();
const reader = testEnv.authenticatedContext('admin-a').firestore();

const elapsed = [];

for (let i = 0; i < SAMPLES; i++) {
  const id = `att-fresh-${i}`;
  const status = i % 2 === 0 ? 'Present' : 'Absent';

  // The teacher writes, as the attendance register does.
  await setDoc(doc(writer, 'attendance', id), {
    attendanceId: id,
    studentId: `stu-${i}`,
    schoolId: SCHOOL,
    teacherId: 'teach-a',
    date: '2026-10-24',
    status,
  });

  // The clock starts once the write has been acknowledged, because that
  // is the moment the PRD calls a "successful update".
  const started = performance.now();

  // A different authorized user polls until the value is visible, which
  // is what a dashboard reload does.
  let visibleAfter = null;
  while (performance.now() - started < TARGET_MS) {
    const snap = await getDoc(doc(reader, 'attendance', id));
    if (snap.exists() && snap.data().status === status) {
      visibleAfter = performance.now() - started;
      break;
    }
  }

  elapsed.push(visibleAfter);
}

const visible = elapsed.filter((ms) => ms !== null);
const withinTarget = visible.filter((ms) => ms <= TARGET_MS);
const sorted = [...visible].sort((a, b) => a - b);
const pct = (n) => ((n / SAMPLES) * 100).toFixed(1);
const at = (q) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))];

console.log('');
console.log('Environment        Firebase Emulator Suite, localhost');
console.log('Journey            teacher writes attendance -> school admin reads it');
console.log(`Successful writes  ${SAMPLES}`);
console.log(`Visible at all     ${visible.length}`);
console.log(`Visible <= 5s      ${withinTarget.length}  (${pct(withinTarget.length)}%)`);
if (sorted.length) {
  console.log(`Median             ${at(0.5).toFixed(1)} ms`);
  console.log(`95th percentile    ${at(0.95).toFixed(1)} ms`);
  console.log(`Slowest            ${sorted[sorted.length - 1].toFixed(1)} ms`);
}
console.log('');
console.log('Not a production measurement: no WAN latency, no real auth,');
console.log('no replication. Does not evidence the PRD V2 target.');
console.log('');

await testEnv.cleanup();
