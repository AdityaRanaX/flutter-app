# EduLens — Day 12 Integration and Reliability Report

Covers data freshness, Firebase integration, Security Rules verification
and cross-role journeys.

Every number below was produced by a command that was actually run. Where
something could not be executed it is marked `NOT RUN` or `BLOCKED` with
the reason, rather than estimated.

---

## 1. Executive summary

Four defects were found and fixed, three of them by tests written to the
requirement rather than to the existing behaviour.

| # | Defect | Severity | Found by |
|---|---|---|---|
| 1 | Any provisioned student could read **every classmate's attendance, fee amounts and student record**, and list those collections school-wide | High | Emulator rules tests |
| 2 | School Information showed the submitted value instead of re-reading the stored record | Medium | Propagation tests |
| 3 | Fee update and attendance register reported success to nobody — the flag was cleared by the reload each one triggers | Medium | Propagation tests |
| 4 | Navigating away during a load crashed the controller: *used after being disposed* | Medium | Reliability tests |

Defect 1 is the significant one, and it **corrects a Day 11 claim**. Day
11 recorded "a student reads only their own attendance and fees" as
satisfied, based on reading the rules source. Running real requests
against the rules engine showed that was wrong. See section 5.

The headline limitation from Day 11 — *runtime Firestore Security Rules
authorization remains unverified* — is now **closed** for the 23 cases in
`test/rules/rules.test.mjs`.

**Recommendation: PASS WITH LIMITATIONS.** The limitations are production
freshness measurement and manual QA, both blocked on a provisioned
Firebase environment, plus deployment of the corrected rules. None is
blocked on code.

---

## 2. Environment

| Item | Value |
|---|---|
| Flutter test host | Windows, `flutter test` on the Dart VM |
| Rules runtime | Firebase Emulator Suite, Firestore emulator, localhost:8080 |
| Emulator driver | `firebase-tools` 13.35.1, pinned locally in `test/rules` |
| Java | 17.0.18 |
| Node | v22.17.1 |
| Firebase project used for rules tests | `edulens-rules-test` (emulator only) |
| Production project | **Not contacted.** No credentials used, nothing deployed |

`firebase-tools` is pinned locally because the current global release
requires JDK 21 and this machine has 17. The pin is a devDependency of
`test/rules` and leaves the globally installed CLI untouched.

---

## 3. Automated command results

Run on the Day 12 branch after all changes.

| Command | Result |
|---|---|
| `git diff --check` | PASS — no whitespace errors |
| `dart format --output=none --set-exit-if-changed lib test` | PASS |
| `flutter analyze` | PASS — no issues found |
| `flutter test` | PASS — **252 passed, 0 failed** |
| `cd test/rules && npm test` | PASS — **23 passed, 0 failed** (emulator) |
| `cd test/rules && npm run freshness` | PASS — see section 4 |

Test counts by type:

| Type | Count | Executes rules? |
|---|---|---|
| Dart unit and widget tests | 252 | No — in-memory fakes |
| Firestore Rules runtime tests | 23 | **Yes** — real rules engine |

---

## 4. Data freshness

### Measured: emulator

`npm run freshness`, 20 samples. A teacher writes an attendance record;
a **different** authorized user (school admin) polls until the value is
visible. Timing starts when the write is acknowledged.

| Journey | Successful updates | Visible ≤ 5s | Freshness rate | Environment |
|---|---|---|---|---|
| Attendance write → authorized read | 20 | 20 | **100%** | Firebase Emulator Suite, localhost |

Median 19.3 ms · 95th percentile 140.5 ms · slowest 140.5 ms.

**This is not evidence for the PRD V2 target.** The target concerns
authorized dashboards in production. The emulator runs on localhost with
no WAN latency, no real Firebase Auth, no replication and no contention.
What it does establish is that the write → authorized-read path works and
that rules evaluation does not add meaningful delay.

### Not measured: production

| Journey | Status | Reason |
|---|---|---|
| Attendance | NOT RUN | No provisioned test accounts or seeded data in the live project |
| Fee update | NOT RUN | As above |
| Exam update | NOT RUN | As above |
| School information | NOT RUN | As above |

Measuring these needs real signed-in users per role, and `cloud_firestore`
needs platform channels, so it cannot run under `flutter test` — it needs
an instrumented `integration_test` run on a device or emulator. Section 9
lists what a human has to set up.

**The PRD V2 freshness target is therefore not yet evidenced.**

### Application-path coverage, measured separately

`test/data_freshness_test.dart` — 13 tests over the controller →
repository → refreshed read path for all four write journeys. These use
fakes: they prove the app re-reads after a write and that the refresh
stays scoped, not how long Firestore takes.

---

## 5. Security Rules verification

`test/rules/rules.test.mjs` — **23 of 23 passing** against the real rules
engine. Run with `cd test/rules && npm install && npm test`.

### The defect found

On `students`, `attendance` and `fees`, read access was granted by this
clause before the student-specific one was reached:

```
getUserSchoolId() == resource.data.schoolId
```

`getUserSchoolId()` reads `users/{uid}.schoolId` for **any** signed-in
user, students included. A provisioned student therefore matched it and
could read every classmate's record, and list those collections for the
whole school. The own-record clause after it was unreachable for them.

Four tests failed on the first run and proved it. The fix limits the
clause to staff:

```
(!isStudent() && getUserSchoolId() == resource.data.schoolId)
```

`exams` deliberately keeps the school-wide clause: a student is meant to
see their school's schedule.

**Day 11 recorded this requirement as satisfied, and that was wrong.** It
was assessed by reading the rules file, and a permissive clause earlier
in an `||` chain makes everything after it unreachable. Reading a rule is
not verification.

### Cases executed

| Area | Cases | Result |
|---|---|---|
| Unauthenticated access to all five collections | 1 | Denied, as required |
| District admin reads across schools | 1 | Allowed, as required |
| School admin scoping, own vs other school | 2 | Correct |
| Ownership transfer via update (fee, student) | 1 | Denied |
| School admin writing into another school | 1 | Denied |
| Teacher attendance: own school, other school, spoofed teacherId | 3 | Correct |
| Teacher exams: own authorship, spoofed authorship | 2 | Correct |
| Student self-access (doc reads and the dashboard's own query) | 2 | Allowed |
| Student reading a classmate's attendance / fee / student record | 3 | Denied *(were allowed before the fix)* |
| Student listing school-wide fees and attendance | 1 | Denied *(was allowed before the fix)* |
| Student reaching another school | 1 | Denied |
| Student exams with and without `users.schoolId` | 2 | Correct — confirms the Day 11 provisioning dependency at runtime |
| Student write attempts (attendance, fee, exam) | 1 | Denied |
| Role escalation and schoolId self-assignment | 1 | Denied |
| Student reading another user profile | 1 | Denied |

### Not covered

- Collections and operations outside the list above, including delete
  paths and the `schools` write rules, are unverified.
- The suite runs against `firestore.rules` in this repository, not
  against what is deployed.

### Deployment

**No rules were deployed.** The corrected file is in the repository only.
Until someone deploys it, production still carries defect 1.

---

## 6. Cross-role core journeys

`test/core_journeys_test.dart` — every role's controller built over one
shared set of repositories, so a write through one role is observed
through another.

| Journey | Test type | Result |
|---|---|---|
| A — District monitoring: schools, attendance, fees, upcoming exams | Unit, fakes | PASS |
| B — School admin updates fee → district figure moves; school info edit survives reload | Unit, fakes | PASS |
| C — Teacher saves register → district figure and that student's own percentage both move | Unit, fakes | PASS |
| D — Teacher schedules an exam → reaches district overview and student schedule, ordered soonest first | Unit, fakes | PASS |
| E — Student read-only dashboard: own records only, empty handled | Unit, fakes | PASS |

```
Journey completion rate = 5 passing / 5 scripted = 100%
```

Denominator is 5. These are **mocked repository journeys**, not live
end-to-end runs: no authentication, no Firestore, no rules. They
establish that the roles agree about the same records and that the
derived figures recompute. They are not evidence for the PRD's core-user-
journey KPI, which implies real sign-in.

---

## 7. Error and retry findings

| Scenario | Result |
|---|---|
| Service unavailable | Error state, spinner cleared |
| Permission denied | Unauthorized state, distinct from empty; message names no record |
| Empty data | Empty state, distinct from error |
| Failed write | Reports failure, stored record untouched, not stuck saving |
| Failed refresh after a successful write | Error surfaced; the write is not silently presented as un-applied |
| Retry after transient failure | Recovers to ready |
| Repeated write | Updates in place, no duplicate record |
| Repeated reload | No accumulation |
| Navigate away mid-load | **Crashed before this work.** Now completes quietly — defect 4 |

### Defect 4

Every controller awaits a repository and then notifies. Disposing the
screen first meant the notification landed on a dead object. Flutter
raises that as an assertion in debug; in release the listener list is
already gone, so it was a genuine crash path.

All eleven controllers had it across 60 notification sites, so the guard
is one shared `SafeNotifier` mixin rather than eleven copies of a flag.
The in-flight load still completes — repositories cannot cancel a read,
and discarding the result is safe because nothing is listening.

---

## 8. Regression and scope

- `flutter analyze` clean; 252 Dart tests pass, including every pre-Day-12
  suite.
- District, school admin and teacher authorization is unchanged by the
  rules fix, confirmed by the same emulator suite that caught the leak.
- No new package was added to the Flutter app. The only new dependencies
  are devDependencies of the rules harness under `test/rules`, which the
  app does not build against.
- No model, collection name, metric formula or architecture was changed.
- `Leave` status, exam-specific attendance, teacher timetable and exam
  lifecycle remain untouched and unresolved.

---

## 9. What is still blocked, and on whom

These need a person with Firebase console access; none is blocked on code.

1. **Deploy the corrected rules.** Until then defect 1 is live. Review
   the diff to `firestore.rules`, then
   `firebase deploy --only firestore:rules`.
2. **Provision test accounts** — one per role, with `users/{uid}.schoolId`
   set for school admin, teacher and student, and a `students` document
   whose id equals the student's Auth UID.
3. **Seed records** against those accounts so dashboards have data.
4. **Production freshness measurement** — once 2 and 3 exist, the four
   journeys in section 4 can be measured on a device via
   `integration_test`.
5. **Manual QA** — every row of the Day 12 manual checklist is currently
   `NOT RUN` for the same reason.

---

## 10. Manual QA checklist

| Scenario | Status |
|---|---|
| Teacher saves attendance; authorized readers retrieve it | NOT RUN — needs provisioned accounts |
| School admin updates fee information | NOT RUN |
| Teacher updates an exam schedule | NOT RUN |
| School information is updated | NOT RUN |
| Student dashboard refreshes | NOT RUN |
| Update becomes visible — time measured | NOT RUN in production; measured in emulator (section 4) |
| Firebase request fails → safe error state | Covered by automated tests; NOT RUN manually |
| Permission denied → protected data stays hidden | Verified at runtime in the emulator; NOT RUN manually |
| Retry does not duplicate writes | Covered by automated tests; NOT RUN manually |
| Existing role screens still work | Covered by 252 automated tests; NOT RUN manually |

---

## 11. Final recommendation

**PASS WITH LIMITATIONS.**

Four defects were found and fixed, including one real privilege leak that
static inspection had missed and that a Day 11 report had wrongly
declared safe. Runtime rules verification now exists and passes.

It is not a clean PASS because the PRD V2 freshness target is not yet
evidenced in production, manual QA has not been performed, and — most
importantly — **the corrected Security Rules are not deployed**, so the
leak remains open in the live project until someone deploys them.
