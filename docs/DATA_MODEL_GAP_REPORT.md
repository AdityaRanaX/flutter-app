# EduLens — Data Model Gap Report

Produced during the Day 5 data-layer work. It compares what the approved
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

## 5. Unresolved gaps

None of these is implemented. Each needs an approved model change first.

| # | Wireframe needs | Model has | Can it be derived? | Status |
|---|---|---|---|---|
| 1 | School address | — | No | **Unresolved** |
| 2 | School contact number | — | No | **Unresolved** |
| 3 | School email | — | No | **Unresolved** |
| 4 | Student roll number | — | No | **Unresolved** |
| 5 | Fee remarks | — | No | **Unresolved** |
| 6 | Teacher's timetable / today's classes | — | No | **Unresolved** |
| 7 | Per-exam student Present/Absent | — | No | **Unresolved** |
| 8 | Attendance status `Leave` | `status` is free text | n/a | **Needs a decision** |
| 9 | Exam status (`Scheduled`) | — | Partly | **Needs a decision** |

Notes on the ones that are easy to get wrong:

**(7) Exam attendance is not daily attendance.** `AttendanceModel` records
a student, a school, a teacher, a date and a status. It has no `examId`,
so there is no way to say whether a student sat a particular exam. A
daily record that happens to fall on an exam date describes a different
event. Day 7's Exam Details therefore ships a student list **without**
Present/Absent labels, and cannot claim full wireframe parity until an
exam-attendance model is approved.

**(8) `Leave`.** The PRD lists Present/Absent; School Details shows
Present/Absent/Leave. `status` is an unconstrained string, so `Leave`
can be stored without a schema change — but no approved writer produces
it today. The attendance percentage formula above already handles it
correctly either way, since it counts `Present` against the total rather
than treating every non-present record as absent.

**(9) Exam status.** `Scheduled` could be derived from the exam date
relative to now, but "scheduled vs completed" is a lifecycle decision,
not a display one. Nothing is stored and nothing is derived until the
rule is approved.

---

## 6. What this allows Days 6 and 7 to build

Supported by the model today, with no further decisions needed:

- District Dashboard: total schools, average attendance, fee overview,
  upcoming exams in the next seven days, attendance-below-70% attention
- School List: name, student count, teacher count, attendance %, fees-paid %, exam count
- School Details: attendance breakdown, fee breakdown, upcoming exams
- District Exam Overview: subject, date, time, school name, Upcoming/All
- Exam Details: subject, school, date, times, class, total students, student list

Blocked until a gap above is resolved:

- School Information (address, contact, email) — gaps 1–3
- Student/Fee Management roll number column — gap 4
- Edit Fee Status remarks field — gap 5
- Teacher Dashboard "today's classes" — gap 6
- Exam Details Present/Absent per student — gap 7
