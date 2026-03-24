"""Core scheduling algorithm: find available teachers, score, and rank."""

import random
from datetime import datetime, timedelta
from .config import (
    WEIGHT_TOTAL_SEMESTER,
    WEIGHT_RECENT_14_DAYS,
    WEIGHT_SAME_DAY,
    DEFAULT_COVERAGE_THRESHOLD,
    DEFAULT_THRESHOLD_WINDOW_DAYS,
)
from .models import CoverageOption
from .db import get_setting


def _get_day_of_week(date_str: str) -> str:
    """Convert ISO date string to day name."""
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    return dt.strftime("%A")


def _get_semester_start(conn) -> str:
    """Get semester start date from settings, default to 90 days ago."""
    start = get_setting(conn, "semester_start")
    if start:
        return start
    default = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
    return default


def _get_threshold(conn) -> int:
    """Get coverage threshold from settings."""
    val = get_setting(conn, "coverage_threshold")
    if val:
        try:
            return int(val)
        except ValueError:
            pass
    return DEFAULT_COVERAGE_THRESHOLD


def _get_threshold_window(conn) -> int:
    """Get threshold window in days from settings."""
    val = get_setting(conn, "threshold_window_days")
    if val:
        try:
            return int(val)
        except ValueError:
            pass
    return DEFAULT_THRESHOLD_WINDOW_DAYS


def record_absence(conn, teacher_id: int, date: str, periods: list, reason: str = "") -> int:
    """Record a teacher absence. Returns the absence ID."""
    periods_str = ",".join(str(p) for p in periods)
    cursor = conn.execute(
        "INSERT INTO absences (teacher_id, date, periods, reason) VALUES (?, ?, ?, ?)",
        (teacher_id, date, periods_str, reason),
    )
    conn.commit()
    return cursor.lastrowid


def get_absent_teacher_schedule(conn, teacher_id: int, date: str, period: int) -> dict:
    """Get what class the absent teacher was supposed to teach."""
    day = _get_day_of_week(date)
    row = conn.execute(
        """SELECT subject, room FROM schedules
           WHERE teacher_id = ? AND day_of_week = ? AND period = ? AND is_free = 0""",
        (teacher_id, day, period),
    ).fetchone()
    if row:
        return {"subject": row["subject"], "room": row["room"]}
    return {"subject": "", "room": ""}


def find_coverage_options(conn, date: str, period: int, absent_teacher_id: int,
                          subject: str = "", room: str = "") -> list:
    """Find and rank available teachers for coverage.

    Returns a list of CoverageOption sorted by fairness score (ascending).
    """
    day = _get_day_of_week(date)
    semester_start = _get_semester_start(conn)
    threshold = _get_threshold(conn)
    threshold_window = _get_threshold_window(conn)

    # Step 1: Find teachers who are free during this period
    candidates = conn.execute(
        """SELECT t.id, t.name, t.department
           FROM teachers t
           JOIN schedules s ON t.id = s.teacher_id
           WHERE s.day_of_week = ? AND s.period = ? AND s.is_free = 1
             AND t.active = 1
             AND t.id != ?""",
        (day, period, absent_teacher_id),
    ).fetchall()

    if not candidates:
        return []

    # Step 2: Apply constraints
    filtered = []
    for c in candidates:
        teacher_id = c["id"]
        constraints = conn.execute(
            "SELECT constraint_type, constraint_value FROM constraints WHERE teacher_id = ?",
            (teacher_id,),
        ).fetchall()

        skip = False
        for con in constraints:
            ctype = con["constraint_type"]
            cvalue = con["constraint_value"]

            if ctype == "no_subject" and subject and cvalue.lower() == subject.lower():
                skip = True
                break

            if ctype == "no_period":
                try:
                    if int(cvalue) == period:
                        skip = True
                        break
                except ValueError:
                    pass

            if ctype == "max_per_week":
                try:
                    max_week = int(cvalue)
                    # Count coverages this week (Mon-Fri containing this date)
                    dt = datetime.strptime(date, "%Y-%m-%d")
                    monday = dt - timedelta(days=dt.weekday())
                    friday = monday + timedelta(days=4)
                    week_count = conn.execute(
                        """SELECT COUNT(*) as cnt FROM coverage_records
                           WHERE covering_teacher_id = ? AND date BETWEEN ? AND ?
                             AND status != 'cancelled'""",
                        (teacher_id, monday.strftime("%Y-%m-%d"), friday.strftime("%Y-%m-%d")),
                    ).fetchone()["cnt"]
                    if week_count >= max_week:
                        skip = True
                        break
                except ValueError:
                    pass

            if ctype == "no_consecutive" and cvalue.lower() in ("true", "1", "yes"):
                # Check if already covering adjacent period today
                adjacent = conn.execute(
                    """SELECT COUNT(*) as cnt FROM coverage_records
                       WHERE covering_teacher_id = ? AND date = ?
                         AND (period = ? OR period = ?)
                         AND status != 'cancelled'""",
                    (teacher_id, date, period - 1, period + 1),
                ).fetchone()["cnt"]
                if adjacent > 0:
                    skip = True
                    break

        # Also check if already covering THIS period on THIS date
        already_covering = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date = ? AND period = ?
                 AND status != 'cancelled'""",
            (teacher_id, date, period),
        ).fetchone()["cnt"]
        if already_covering > 0:
            skip = True

        if not skip:
            filtered.append(c)

    # Step 3: Score candidates
    options = []
    fourteen_days_ago = (datetime.strptime(date, "%Y-%m-%d") - timedelta(days=14)).strftime("%Y-%m-%d")
    threshold_start = (datetime.strptime(date, "%Y-%m-%d") - timedelta(days=threshold_window)).strftime("%Y-%m-%d")

    for c in filtered:
        teacher_id = c["id"]

        total = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (teacher_id, semester_start),
        ).fetchone()["cnt"]

        recent = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (teacher_id, fourteen_days_ago),
        ).fetchone()["cnt"]

        today_count = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date = ? AND status != 'cancelled'""",
            (teacher_id, date),
        ).fetchone()["cnt"]

        score = (
            total * WEIGHT_TOTAL_SEMESTER
            + recent * WEIGHT_RECENT_14_DAYS
            + today_count * WEIGHT_SAME_DAY
        )

        # Check threshold
        threshold_count = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (teacher_id, threshold_start),
        ).fetchone()["cnt"]

        flagged = threshold_count >= threshold
        flag_reason = ""
        if flagged:
            flag_reason = f"{threshold_count} coverages in last {threshold_window} days (threshold: {threshold})"

        options.append(CoverageOption(
            teacher_id=teacher_id,
            teacher_name=c["name"],
            department=c["department"],
            score=score,
            coverages_this_semester=total,
            coverages_last_14_days=recent,
            coverages_today=today_count,
            flagged=flagged,
            flag_reason=flag_reason,
        ))

    # Sort by score ascending, shuffle within same score for fairness
    options.sort(key=lambda x: x.score)

    # Group by score and shuffle within groups
    if options:
        groups = []
        current_score = options[0].score
        current_group = []
        for opt in options:
            if opt.score == current_score:
                current_group.append(opt)
            else:
                random.shuffle(current_group)
                groups.extend(current_group)
                current_score = opt.score
                current_group = [opt]
        random.shuffle(current_group)
        groups.extend(current_group)
        options = groups

    return options


def assign_coverage(conn, absence_id: int, covering_teacher_id: int,
                    date: str, period: int, subject: str = "", room: str = "") -> int:
    """Assign a teacher to cover a period. Returns coverage record ID."""
    cursor = conn.execute(
        """INSERT INTO coverage_records
           (absence_id, covering_teacher_id, date, period, subject, room, status)
           VALUES (?, ?, ?, ?, ?, ?, 'assigned')""",
        (absence_id, covering_teacher_id, date, period, subject, room),
    )
    conn.commit()
    return cursor.lastrowid


def cancel_coverage(conn, coverage_id: int) -> None:
    """Cancel a coverage assignment."""
    conn.execute(
        "UPDATE coverage_records SET status = 'cancelled' WHERE id = ?",
        (coverage_id,),
    )
    conn.commit()
