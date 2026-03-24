"""Coverage history queries and fairness reporting."""

from datetime import datetime, timedelta
from .db import get_setting
from .config import DEFAULT_COVERAGE_THRESHOLD, DEFAULT_THRESHOLD_WINDOW_DAYS


def get_teacher_coverage_history(conn, teacher_id: int = None,
                                  start_date: str = None, end_date: str = None) -> list:
    """Get coverage records, optionally filtered by teacher and date range."""
    query = """
        SELECT cr.id, cr.date, cr.period, cr.subject, cr.room, cr.status,
               cr.assigned_at, t_covering.name as covering_teacher,
               t_absent.name as absent_teacher
        FROM coverage_records cr
        JOIN teachers t_covering ON cr.covering_teacher_id = t_covering.id
        JOIN absences a ON cr.absence_id = a.id
        JOIN teachers t_absent ON a.teacher_id = t_absent.id
        WHERE 1=1
    """
    params = []

    if teacher_id is not None:
        query += " AND cr.covering_teacher_id = ?"
        params.append(teacher_id)

    if start_date:
        query += " AND cr.date >= ?"
        params.append(start_date)

    if end_date:
        query += " AND cr.date <= ?"
        params.append(end_date)

    query += " ORDER BY cr.date DESC, cr.period ASC"

    return conn.execute(query, params).fetchall()


def get_fairness_report(conn, semester_start: str = None) -> list:
    """Generate a fairness report for all active teachers.

    Returns a list of dicts with coverage stats per teacher.
    """
    if not semester_start:
        semester_start = get_setting(conn, "semester_start")
        if not semester_start:
            semester_start = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")

    threshold = DEFAULT_COVERAGE_THRESHOLD
    val = get_setting(conn, "coverage_threshold")
    if val:
        try:
            threshold = int(val)
        except ValueError:
            pass

    threshold_window = DEFAULT_THRESHOLD_WINDOW_DAYS
    val = get_setting(conn, "threshold_window_days")
    if val:
        try:
            threshold_window = int(val)
        except ValueError:
            pass

    today = datetime.now().strftime("%Y-%m-%d")
    fourteen_days_ago = (datetime.now() - timedelta(days=14)).strftime("%Y-%m-%d")
    threshold_start = (datetime.now() - timedelta(days=threshold_window)).strftime("%Y-%m-%d")

    teachers = conn.execute(
        "SELECT id, name, department FROM teachers WHERE active = 1 ORDER BY name"
    ).fetchall()

    report = []
    for t in teachers:
        tid = t["id"]

        total = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (tid, semester_start),
        ).fetchone()["cnt"]

        recent = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (tid, fourteen_days_ago),
        ).fetchone()["cnt"]

        in_window = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date >= ? AND status != 'cancelled'""",
            (tid, threshold_start),
        ).fetchone()["cnt"]

        today_count = conn.execute(
            """SELECT COUNT(*) as cnt FROM coverage_records
               WHERE covering_teacher_id = ? AND date = ? AND status != 'cancelled'""",
            (tid, today),
        ).fetchone()["cnt"]

        flagged = in_window >= threshold
        flag_reason = ""
        if flagged:
            flag_reason = f"{in_window} coverages in {threshold_window} days (threshold: {threshold})"

        report.append({
            "teacher_id": tid,
            "name": t["name"],
            "department": t["department"],
            "semester_total": total,
            "last_14_days": recent,
            "in_threshold_window": in_window,
            "today": today_count,
            "flagged": flagged,
            "flag_reason": flag_reason,
        })

    # Sort by semester total descending
    report.sort(key=lambda x: x["semester_total"], reverse=True)
    return report


def get_absences_for_date(conn, date: str) -> list:
    """Get all absences for a given date with coverage status."""
    absences = conn.execute(
        """SELECT a.id, a.teacher_id, a.date, a.periods, a.reason,
                  t.name as teacher_name
           FROM absences a
           JOIN teachers t ON a.teacher_id = t.id
           WHERE a.date = ?
           ORDER BY t.name""",
        (date,),
    ).fetchall()

    results = []
    for a in absences:
        periods = [int(p) for p in a["periods"].split(",") if p.strip()]
        period_coverage = {}

        for p in periods:
            coverage = conn.execute(
                """SELECT cr.id, t.name as covering_teacher, cr.status
                   FROM coverage_records cr
                   JOIN teachers t ON cr.covering_teacher_id = t.id
                   WHERE cr.absence_id = ? AND cr.period = ? AND cr.status != 'cancelled'""",
                (a["id"], p),
            ).fetchone()

            if coverage:
                period_coverage[p] = {
                    "coverage_id": coverage["id"],
                    "covering_teacher": coverage["covering_teacher"],
                    "status": coverage["status"],
                }
            else:
                period_coverage[p] = None

        results.append({
            "absence_id": a["id"],
            "teacher_id": a["teacher_id"],
            "teacher_name": a["teacher_name"],
            "date": a["date"],
            "periods": periods,
            "reason": a["reason"],
            "period_coverage": period_coverage,
        })

    return results
