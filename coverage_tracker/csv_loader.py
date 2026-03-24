"""CSV loading and validation for teachers, schedules, and constraints."""

import csv
from .config import MIN_PERIOD, MAX_PERIOD, VALID_DAYS

VALID_CONSTRAINT_TYPES = {"no_subject", "no_period", "max_per_week", "no_consecutive"}


def load_teachers_csv(filepath: str) -> tuple:
    """Parse teachers CSV. Returns (records, errors).

    Expected columns: name, department, email
    """
    records = []
    errors = []
    seen_names = set()

    try:
        with open(filepath, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)

            if "name" not in (reader.fieldnames or []):
                return [], ["CSV must have a 'name' column"]

            for i, row in enumerate(reader, start=2):
                name = row.get("name", "").strip()
                if not name:
                    errors.append(f"Row {i}: empty name")
                    continue
                if name in seen_names:
                    errors.append(f"Row {i}: duplicate name '{name}'")
                    continue

                seen_names.add(name)
                records.append({
                    "name": name,
                    "department": row.get("department", "").strip(),
                    "email": row.get("email", "").strip(),
                })
    except FileNotFoundError:
        return [], [f"File not found: {filepath}"]
    except Exception as e:
        return [], [f"Error reading file: {e}"]

    return records, errors


def load_schedules_csv(filepath: str) -> tuple:
    """Parse schedules CSV. Returns (records, errors).

    Expected columns: teacher_name, day_of_week, period, subject, room, is_free
    """
    records = []
    errors = []

    required = {"teacher_name", "day_of_week", "period", "is_free"}

    try:
        with open(filepath, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            fields = set(reader.fieldnames or [])

            missing = required - fields
            if missing:
                return [], [f"CSV missing required columns: {', '.join(missing)}"]

            for i, row in enumerate(reader, start=2):
                teacher_name = row.get("teacher_name", "").strip()
                day = row.get("day_of_week", "").strip()
                period_str = row.get("period", "").strip()
                is_free_str = row.get("is_free", "").strip()

                if not teacher_name:
                    errors.append(f"Row {i}: empty teacher_name")
                    continue

                if day not in VALID_DAYS:
                    errors.append(f"Row {i}: invalid day '{day}'. Must be one of {VALID_DAYS}")
                    continue

                try:
                    period = int(period_str)
                    if period < MIN_PERIOD or period > MAX_PERIOD:
                        errors.append(f"Row {i}: period {period} out of range ({MIN_PERIOD}-{MAX_PERIOD})")
                        continue
                except ValueError:
                    errors.append(f"Row {i}: invalid period '{period_str}'")
                    continue

                is_free = is_free_str in ("1", "true", "True", "yes", "Yes")

                records.append({
                    "teacher_name": teacher_name,
                    "day_of_week": day,
                    "period": period,
                    "subject": row.get("subject", "").strip(),
                    "room": row.get("room", "").strip(),
                    "is_free": is_free,
                })
    except FileNotFoundError:
        return [], [f"File not found: {filepath}"]
    except Exception as e:
        return [], [f"Error reading file: {e}"]

    return records, errors


def load_constraints_csv(filepath: str) -> tuple:
    """Parse constraints CSV. Returns (records, errors).

    Expected columns: teacher_name, constraint_type, constraint_value
    """
    records = []
    errors = []

    required = {"teacher_name", "constraint_type", "constraint_value"}

    try:
        with open(filepath, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            fields = set(reader.fieldnames or [])

            missing = required - fields
            if missing:
                return [], [f"CSV missing required columns: {', '.join(missing)}"]

            for i, row in enumerate(reader, start=2):
                teacher_name = row.get("teacher_name", "").strip()
                ctype = row.get("constraint_type", "").strip()
                cvalue = row.get("constraint_value", "").strip()

                if not teacher_name:
                    errors.append(f"Row {i}: empty teacher_name")
                    continue

                if ctype not in VALID_CONSTRAINT_TYPES:
                    errors.append(
                        f"Row {i}: invalid constraint_type '{ctype}'. "
                        f"Must be one of {VALID_CONSTRAINT_TYPES}"
                    )
                    continue

                if not cvalue:
                    errors.append(f"Row {i}: empty constraint_value")
                    continue

                records.append({
                    "teacher_name": teacher_name,
                    "constraint_type": ctype,
                    "constraint_value": cvalue,
                })
    except FileNotFoundError:
        return [], [f"File not found: {filepath}"]
    except Exception as e:
        return [], [f"Error reading file: {e}"]

    return records, errors


def save_teachers(conn, records: list) -> tuple:
    """Insert/update teachers in the database. Returns (count_saved, errors)."""
    errors = []
    count = 0

    for rec in records:
        try:
            conn.execute(
                """INSERT INTO teachers (name, department, email, active)
                   VALUES (?, ?, ?, 1)
                   ON CONFLICT(name) DO UPDATE SET
                       department = excluded.department,
                       email = excluded.email,
                       active = 1""",
                (rec["name"], rec["department"], rec["email"]),
            )
            count += 1
        except Exception as e:
            errors.append(f"Error saving teacher '{rec['name']}': {e}")

    conn.commit()
    return count, errors


def save_schedules(conn, records: list) -> tuple:
    """Save schedules, replacing existing entries for included teachers."""
    errors = []
    count = 0

    # Group by teacher to do per-teacher replacement
    teacher_names = set(r["teacher_name"] for r in records)

    for name in teacher_names:
        row = conn.execute(
            "SELECT id FROM teachers WHERE name = ?", (name,)
        ).fetchone()
        if not row:
            errors.append(f"Teacher '{name}' not found in database. Load teachers first.")
            continue

        teacher_id = row["id"]
        # Delete existing schedules for this teacher
        conn.execute("DELETE FROM schedules WHERE teacher_id = ?", (teacher_id,))

    for rec in records:
        row = conn.execute(
            "SELECT id FROM teachers WHERE name = ?", (rec["teacher_name"],)
        ).fetchone()
        if not row:
            continue  # Already reported above

        try:
            conn.execute(
                """INSERT INTO schedules (teacher_id, day_of_week, period, subject, room, is_free)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (row["id"], rec["day_of_week"], rec["period"],
                 rec["subject"], rec["room"], 1 if rec["is_free"] else 0),
            )
            count += 1
        except Exception as e:
            errors.append(f"Error saving schedule for '{rec['teacher_name']}': {e}")

    conn.commit()
    return count, errors


def save_constraints(conn, records: list) -> tuple:
    """Save constraints, replacing existing entries for included teachers."""
    errors = []
    count = 0

    teacher_names = set(r["teacher_name"] for r in records)

    for name in teacher_names:
        row = conn.execute(
            "SELECT id FROM teachers WHERE name = ?", (name,)
        ).fetchone()
        if not row:
            errors.append(f"Teacher '{name}' not found in database. Load teachers first.")
            continue

        teacher_id = row["id"]
        conn.execute("DELETE FROM constraints WHERE teacher_id = ?", (teacher_id,))

    for rec in records:
        row = conn.execute(
            "SELECT id FROM teachers WHERE name = ?", (rec["teacher_name"],)
        ).fetchone()
        if not row:
            continue

        try:
            conn.execute(
                """INSERT INTO constraints (teacher_id, constraint_type, constraint_value)
                   VALUES (?, ?, ?)""",
                (row["id"], rec["constraint_type"], rec["constraint_value"]),
            )
            count += 1
        except Exception as e:
            errors.append(f"Error saving constraint for '{rec['teacher_name']}': {e}")

    conn.commit()
    return count, errors
