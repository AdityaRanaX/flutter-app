# EduLens — Data Model Gap Report

Produced during the Day 5 data-layer work and updated following the approved model extension task. It compares what the approved
wireframes display against what the PRD data model actually stores, and
records the decisions that Days 6 and 7 build on.

The rule throughout: **a gap is written down, not invented**. Where a
screen needs something the model does not have, that is recorded here as
unresolved rather than guessed at in code.

---

## 1. Collection naming

The PRD writes collections capitalised (`Users/{uid}`). The deployed
`firestore.rules` and the existing Day 3 user bootstrap both use
lower-case (`users`). The code is self-consistent and already live, so
**lower-case wins**, and the names are now centralised in
`lib/core/constants/firestore_collections.dart` so no repository spells
them out again.

| Collection | Document id |
|---|---|
| `users` | Firebase Auth UID |
| `schools` | `schoolId` |
| `students` | `studentId` |
| `attendance` | `attendanceId` |
| `fees` | `feeId` |
| `exams` | `examId` |

Each document also stores its own id as a field, because the models read
the field rather than the document path.

---

## 2. Dates are strings, and the format is now fixed

`ExamModel.date`, `ExamModel.startTime`, `ExamModel.endTime` and
`AttendanceModel.date` are all `String`, and every `fromMap` reads them
with `as String?`. A Firestore **timestamp** written into those fields
deserialises to `null` and then to `''` — the record silently becomes
unusable rather than failing loudly.

**Decision: dates are stored as `yyyy-MM-dd` strings and times as `HH:mm`
(24-hour).**

Two things follow from this, and Day 7 depends on both:

- `DateTime.parse` accepts `yyyy-MM-dd` directly, so the upcoming/past
  comparison needs no custom parser.
- Lexicographic string ordering equals chronological ordering, so exams
  can be sorted and range-filtered as plain strings.

Anything written in another format (`10 Oct 2026`) breaks both
properties. The seeding tool in `tool/` writes this format.

---

## 3. Stored vs derived

Nothing below is stored on the school document, and none of it should
be. Each is computed from the source records by the layer above the
repositories — the repositories return records, not metrics.

| Wireframe value | Derived from |
|---|---|
| Student count | `students` where `schoolId` matches |
| Teacher count | `users` where `role == 'teacher'` and `schoolId` matches |
| Attendance % | `attendance` records for the school |
| Fees-paid % | `fees` records for the school |
| Exam count / upcoming exams | `exams` records, filtered by date |
| Exam total students | `students` where `schoolId` **and** `className` match the exam |

Storing these as duplicated fields would mean every attendance or fee
write also has to update a counter, and any missed update silently shows
a wrong number on a dashboard.

---

## 4. Agreed metric formulas

The PRD requires these to be stated rather than chosen ad hoc. They are
**not implemented in the data layer** — the repositories stay free of
presentation logic — but Day 6 implements exactly these and nothing else.

**Attendance percentage**

```
present records ÷ all records in scope × 100
```

where "present" means `status == 'Present'`. Records with any other
status count towards the denominator. Scope is the school for the School
List, and all authorised records for the district average. With no
records, the result is "no data", not 0%.

**Fees-paid percentage**

```
sum(paidAmount) ÷ sum(totalDue) × 100
```

Amount-weighted rather than counting Paid records, so a part-paid fee is
represented honestly. With `sum(totalDue) == 0`, the result is "no data",
not 100%.

**Fee breakdown (School Details)** counts records by `status` into Paid /
Partial / Outstanding, which is a different question from the percentage
above and intentionally computed separately.

**Attention threshold** — attendance **below 70%**, which the District
Dashboard wireframe states explicitly.

---

## 5. Model Gaps Status Summary

### A. IMPLEMENTED Model Extensions (Backward-Compatible)

| # | Feature / Field | Model Extended | Property Type | Implementation Details |
|---|---|---|---|---|
| 1 | School Address | `SchoolModel` | `String? address` | Optional address string for school location details. |
| 2 | School Contact Number | `SchoolModel` | `String? contactNumber` | Optional phone/contact number string. |
| 3 | School Email | `SchoolModel` | `String? email` | Optional school email address string. |
| 4 | Student Roll Number | `StudentModel` | `String? rollNumber` | Optional roll number string (preserves distinct `studentId`). |
| 5 | Fee Remarks | `FeeModel` | `String? remarks` | Optional latest remarks note on fee status updates. |

*Note: All 5 extended fields are optional (`String?`) to guarantee 100% backward compatibility with legacy Firestore documents.*

---

### B. STILL UNRESOLVED Gaps (Requires Future Architectural Design)

| # | Wireframe Needs | Current Model | Why Unresolved |
|---|---|---|---|
| 6 | Teacher Timetable / Today's Classes | — | Requires an approved schema for class assignments, schedule, and teacher-class relationships. |
| 7 | Per-Exam Student Attendance | — | Daily `AttendanceModel` lacks `examId`. Treating daily attendance as exam attendance is invalid. |
| 8 | Attendance Status `Leave` | Free-text `status` | PRD specifies Present/Absent; wireframe shows Leave. No approved writer produces `Leave` today. |
| 9 | Exam Status (`Scheduled`) | — | `Scheduled` is a lifecycle status requiring team decision rather than date-inferred guessing. |

---

### C. FOLLOW-UP UI Work Required

- **School Information Screen**: Update UI forms to capture and display `address`, `contactNumber`, and `email`.
- **Student/Fee Management Screen**: Update UI table columns to render `rollNumber`.
- **Edit Fee Status Screen**: Update form to capture and save `remarks`.
- **Legacy Record Migration**: Run optional migration scripts if backfilling legacy documents is required.

---

## 6. Scope Overview

Supported by the model today:

- District Dashboard: total schools, average attendance, fee overview, upcoming exams in seven days, attention alerts
- School List: name, student count, teacher count, attendance %, fees-paid %, exam count
- School Details: attendance breakdown, fee breakdown, upcoming exams
- District Exam Overview: subject, date, time, school name, Upcoming/All
- Exam Details: subject, school, date, times, class, total students, student list
- Student Dashboard: the signed-in student's own attendance percentage, fee status and upcoming exams, read-only
- Extended Fields: School contact/address/email, Student roll number, Fee remarks

---

## 7. Student Dashboard identity and authorization

Recorded during the Day 11 student-access review. The Student Dashboard
reads a single student's own attendance, fees and examination schedule,
so the question it raises is not "what does the model store" but "how
does an authenticated user become a known student".

### The enforced identity mapping

`UserModel` holds `uid`, and `StudentModel` holds `studentId`. **Neither
model carries a field linking the two.** The link is not absent, though —
it is already asserted by the deployed `firestore.rules`, in three
places:

```
// students
(isStudent() && (resource.data.studentId == request.auth.uid ||
                 studentId == request.auth.uid))
// attendance, fees
(isStudent() && resource.data.studentId == request.auth.uid)
```

**Decision: the approved mapping is `students.studentId == Firebase Auth
UID`,** because the rules already enforce exactly that and nothing else
can be read by a student. The app layer resolves a student's records from
`UserModel.uid` on that basis.

This is written down rather than introduced: adding a `studentId` field
to `UserModel` would create a second source of truth that the rules do
not check, and a record whose two identifiers disagreed would read as
authorised to the app and unauthorised to Firestore.

A consequence worth stating: a student whose `students` document id and
`studentId` field do not equal their Auth UID is invisible to themselves.
That is an **unavailable identity mapping**, and the dashboard reports it
as an error rather than as an empty record — "we cannot identify you" and
"you have no attendance yet" are different facts.

### Exams are school-scoped, and that is a provisioning dependency

Attendance and fees are matched to the student directly. Exams are not —
an exam has no `studentId`, so the rule is school-scoped:

```
// exams
allow read: if isDistrictAdmin() || getUserSchoolId() == resource.data.schoolId
```

`getUserSchoolId()` reads `users/{uid}.schoolId`. The `users` create rule
deliberately forbids a self-registering student from choosing one:

```
request.resource.data.role == 'student' &&
(!('schoolId' in request.resource.data) || request.resource.data.schoolId == null ||
  request.resource.data.schoolId == '')
```

**So a self-registered student has no `schoolId` and cannot read any
exam.** Their upcoming-examinations section is permission-denied until a
School Admin or District Admin sets `schoolId` on their user profile —
which the rules already permit those roles to do.

This is a **provisioning requirement, not a rules defect**, and it is
deliberately not fixed by widening the exam read rule. Granting students
a broader exam read would hand every student every school's examination
schedule to remove one setup step. The dashboard therefore surfaces the
denial as its unauthorized state.

### Requirement verification

Checked by inspecting the deployed rules. **No rule was changed**: every
Day 11 authorization requirement is already satisfied.

| # | Requirement | Enforced by | Status |
|---|---|---|---|
| 1 | Only authenticated users reach student data | `isSignedIn()` guards every collection | Satisfied |
| 2 | A student reads only their own attendance / fees | `resource.data.studentId == request.auth.uid` | Satisfied |
| 2a | A student reads their own examination schedule | `getUserSchoolId() == resource.data.schoolId` | Satisfied, requires `users.schoolId` |
| 3 | A student cannot write attendance | create/update limited to district, school admin, teacher | Satisfied |
| 4 | A student cannot change fee amounts or status | create/update limited to district, school admin | Satisfied |
| 5 | A student cannot write examinations | create/update limited to district, school admin, teacher | Satisfied |
| 6 | Staff keep their existing access | rules untouched by Day 11 | Satisfied |
| 7 | Substituting another id grants nothing | reads match on stored `resource.data`, never on client input | Satisfied |

Requirement 7 holds because every student read compares `request.auth.uid`
against the **stored** document rather than against anything the client
sends. Asking for another student's document returns a denial, not that
student's record.

### Verification limits

The table above is **static inspection of the rules source**. The
Firebase Emulator Suite is not configured in this repository, and no
rules test harness exists, so:

> **Runtime Firestore Security Rules authorization remains unverified.**

Widget and controller tests in `test/` run against the in-memory fakes in
`test/support/fake_repositories.dart`. They verify how the dashboard
*responds* to a permission denial. They execute no rules and prove
nothing about whether Firestore would actually deny the request. Rules
were not deployed as part of this work.
