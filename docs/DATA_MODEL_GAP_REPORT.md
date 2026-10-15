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
- Extended Fields: School contact/address/email, Student roll number, Fee remarks
