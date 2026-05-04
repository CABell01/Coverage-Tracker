"""Flask web application for the Teacher Coverage Scheduler."""

import os
import tempfile
from datetime import datetime, timedelta
from flask import Flask, render_template, request, redirect, url_for, flash

from .db import get_connection, init_db, get_setting, set_setting
from flask import Response
from .csv_loader import (
    load_teachers_csv, load_schedules_csv, load_constraints_csv,
    save_teachers, save_schedules, save_constraints,
    load_unified_csv, save_unified,
)
from .scheduler import (
    record_absence, get_absent_teacher_schedule,
    find_coverage_options, assign_coverage, cancel_coverage,
)
from .history import (
    get_teacher_coverage_history, get_fairness_report, get_absences_for_date,
)
from .config import DEFAULT_COVERAGE_THRESHOLD, DEFAULT_THRESHOLD_WINDOW_DAYS, MAX_PERIOD


def seed_sample_data(conn):
    """Load sample data if the database has no teachers."""
    count = conn.execute("SELECT COUNT(*) as cnt FROM teachers").fetchone()["cnt"]
    if count > 0:
        return

    base = os.path.join(os.path.dirname(__file__), "..", "data")
    unified_path = os.path.join(base, "sample_unified.csv")

    if os.path.exists(unified_path):
        teachers, schedules, constraints, _ = load_unified_csv(unified_path)
        if teachers:
            save_unified(conn, teachers, schedules, constraints)


def create_app(db_path=None):
    """Create and configure the Flask application."""
    app = Flask(__name__)
    app.secret_key = "coverage-tracker-secret-key"

    if db_path is None:
        db_path = os.environ.get("CT_DB_PATH", "coverage_tracker.db")

    # Use a temp file for :memory: so multiple connections share the same DB
    if db_path == ":memory:":
        _tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        db_path = _tmp.name
        _tmp.close()

    def get_db():
        conn = get_connection(db_path)
        init_db(conn)
        return conn

    # Seed sample data on startup
    conn = get_db()
    seed_sample_data(conn)
    conn.close()

    @app.route("/")
    def dashboard():
        conn = get_db()
        today = datetime.now().strftime("%Y-%m-%d")

        teacher_count = conn.execute(
            "SELECT COUNT(*) as cnt FROM teachers WHERE active = 1"
        ).fetchone()["cnt"]

        absences = get_absences_for_date(conn, today)
        absence_count = len(absences)

        uncovered_count = 0
        for ab in absences:
            for p in ab["periods"]:
                class_info = get_absent_teacher_schedule(conn, ab["teacher_id"], today, p)
                if class_info["subject"] and not ab["period_coverage"].get(p):
                    uncovered_count += 1

        report = get_fairness_report(conn)
        flagged_teachers = [t for t in report if t["flagged"]]
        flagged_count = len(flagged_teachers)

        conn.close()
        return render_template(
            "dashboard.html",
            active_page="dashboard",
            today=today,
            teacher_count=teacher_count,
            absence_count=absence_count,
            uncovered_count=uncovered_count,
            flagged_count=flagged_count,
            absences=absences,
            flagged_teachers=flagged_teachers,
        )

    @app.route("/teachers")
    def teachers():
        conn = get_db()
        rows = conn.execute(
            "SELECT id, name, department, email, active FROM teachers ORDER BY name"
        ).fetchall()
        conn.close()
        return render_template("teachers.html", active_page="teachers", teachers=rows)

    @app.route("/absences")
    def absences():
        conn = get_db()
        selected_date = request.args.get("date", datetime.now().strftime("%Y-%m-%d"))
        absence_list = get_absences_for_date(conn, selected_date)
        conn.close()
        return render_template(
            "absences.html",
            active_page="absences",
            absences=absence_list,
            selected_date=selected_date,
        )

    @app.route("/absences/new", methods=["GET", "POST"])
    def new_absence():
        conn = get_db()

        if request.method == "POST":
            teacher_id = int(request.form["teacher_id"])
            date = request.form["date"]
            periods = request.form.getlist("periods")
            reason = request.form.get("reason", "")

            if not periods:
                flash("Please select at least one period.", "error")
                teachers = conn.execute(
                    "SELECT id, name, department FROM teachers WHERE active = 1 ORDER BY name"
                ).fetchall()
                conn.close()
                return render_template(
                    "absence_form.html",
                    active_page="new_absence",
                    teachers=teachers,
                    today=date,
                    max_period=MAX_PERIOD,
                )

            period_list = [int(p) for p in periods]
            absence_id = record_absence(conn, teacher_id, date, period_list, reason)

            teacher = conn.execute("SELECT name FROM teachers WHERE id = ?", (teacher_id,)).fetchone()
            flash(f"Absence recorded for {teacher['name']} on {date}.", "success")
            conn.close()
            return redirect(url_for("absence_detail", absence_id=absence_id))

        teachers = conn.execute(
            "SELECT id, name, department FROM teachers WHERE active = 1 ORDER BY name"
        ).fetchall()
        conn.close()
        return render_template(
            "absence_form.html",
            active_page="new_absence",
            teachers=teachers,
            today=datetime.now().strftime("%Y-%m-%d"),
            max_period=MAX_PERIOD,
        )

    @app.route("/absences/<int:absence_id>")
    def absence_detail(absence_id):
        conn = get_db()

        absence_row = conn.execute(
            """SELECT a.id, a.teacher_id, a.date, a.periods, a.reason, t.name as teacher_name
               FROM absences a JOIN teachers t ON a.teacher_id = t.id
               WHERE a.id = ?""",
            (absence_id,),
        ).fetchone()

        if not absence_row:
            flash("Absence not found.", "error")
            conn.close()
            return redirect(url_for("absences"))

        periods = [int(p) for p in absence_row["periods"].split(",") if p.strip()]

        # Build period coverage info
        period_coverage = {}
        for p in periods:
            cov = conn.execute(
                """SELECT cr.id as coverage_id, t.name as covering_teacher, cr.status
                   FROM coverage_records cr JOIN teachers t ON cr.covering_teacher_id = t.id
                   WHERE cr.absence_id = ? AND cr.period = ? AND cr.status != 'cancelled'""",
                (absence_id, p),
            ).fetchone()
            if cov:
                period_coverage[p] = {
                    "coverage_id": cov["coverage_id"],
                    "covering_teacher": cov["covering_teacher"],
                    "status": cov["status"],
                }
            else:
                period_coverage[p] = None

        absence = {
            "absence_id": absence_row["id"],
            "teacher_id": absence_row["teacher_id"],
            "teacher_name": absence_row["teacher_name"],
            "date": absence_row["date"],
            "periods": periods,
            "reason": absence_row["reason"],
            "period_coverage": period_coverage,
        }

        # Get class info and coverage options for each uncovered period
        class_infos = {}
        options = {}
        for p in periods:
            info = get_absent_teacher_schedule(conn, absence["teacher_id"], absence["date"], p)
            class_infos[p] = info
            if info["subject"] and not period_coverage.get(p):
                opts = find_coverage_options(
                    conn, absence["date"], p, absence["teacher_id"],
                    info["subject"], info["room"],
                )
                options[p] = opts

        conn.close()
        return render_template(
            "absence_detail.html",
            active_page="absences",
            absence=absence,
            class_infos=class_infos,
            options=options,
        )

    @app.route("/coverage/assign", methods=["POST"])
    def assign_coverage_route():
        conn = get_db()
        absence_id = int(request.form["absence_id"])
        teacher_id = int(request.form["teacher_id"])
        date = request.form["date"]
        period = int(request.form["period"])
        subject = request.form.get("subject", "")
        room = request.form.get("room", "")

        assign_coverage(conn, absence_id, teacher_id, date, period, subject, room)

        teacher = conn.execute("SELECT name FROM teachers WHERE id = ?", (teacher_id,)).fetchone()
        flash(f"Assigned {teacher['name']} to cover Period {period}.", "success")
        conn.close()
        return redirect(url_for("absence_detail", absence_id=absence_id))

    @app.route("/coverage/cancel", methods=["POST"])
    def cancel_coverage_route():
        conn = get_db()
        coverage_id = int(request.form["coverage_id"])
        absence_id = int(request.form["absence_id"])

        cancel_coverage(conn, coverage_id)
        flash("Coverage cancelled.", "success")
        conn.close()
        return redirect(url_for("absence_detail", absence_id=absence_id))

    @app.route("/history")
    def history():
        conn = get_db()

        teacher_id = request.args.get("teacher_id", type=int)
        start_date = request.args.get("start_date", "")
        end_date = request.args.get("end_date", "")

        records = get_teacher_coverage_history(
            conn,
            teacher_id=teacher_id if teacher_id else None,
            start_date=start_date if start_date else None,
            end_date=end_date if end_date else None,
        )

        teachers = conn.execute(
            "SELECT id, name FROM teachers WHERE active = 1 ORDER BY name"
        ).fetchall()

        conn.close()
        return render_template(
            "history.html",
            active_page="history",
            records=records,
            teachers=teachers,
            selected_teacher=teacher_id,
            start_date=start_date,
            end_date=end_date,
        )

    @app.route("/fairness")
    def fairness():
        conn = get_db()
        report = get_fairness_report(conn)

        totals = [r["semester_total"] for r in report]
        avg_coverages = sum(totals) / len(totals) if totals else 0
        flagged_count = sum(1 for r in report if r["flagged"])
        max_coverages = max(totals) if totals else 0
        min_coverages = min(totals) if totals else 0

        conn.close()
        return render_template(
            "fairness.html",
            active_page="fairness",
            report=report,
            avg_coverages=avg_coverages,
            flagged_count=flagged_count,
            max_coverages=max_coverages,
            min_coverages=min_coverages,
        )

    @app.route("/upload")
    def upload():
        conn = get_db()
        teacher_count = conn.execute("SELECT COUNT(*) as cnt FROM teachers").fetchone()["cnt"]
        schedule_count = conn.execute("SELECT COUNT(*) as cnt FROM schedules").fetchone()["cnt"]
        constraint_count = conn.execute("SELECT COUNT(*) as cnt FROM constraints").fetchone()["cnt"]
        conn.close()
        return render_template(
            "upload.html",
            active_page="upload",
            teacher_count=teacher_count,
            schedule_count=schedule_count,
            constraint_count=constraint_count,
        )

    @app.route("/upload/data", methods=["POST"])
    def upload_data():
        conn = get_db()
        file = request.files.get("file")
        if not file:
            flash("No file selected.", "error")
            conn.close()
            return redirect(url_for("upload"))

        with tempfile.NamedTemporaryFile(mode="wb", suffix=".csv", delete=False) as tmp:
            file.save(tmp)
            tmp_path = tmp.name

        try:
            teachers, schedules, constraints, errors = load_unified_csv(tmp_path)
            if errors:
                for e in errors:
                    flash(f"Validation: {e}", "warning")
            if teachers:
                counts, save_errors = save_unified(conn, teachers, schedules, constraints)
                for e in save_errors:
                    flash(f"Save error: {e}", "error")
                flash(
                    f"Loaded {counts['teachers']} teachers, "
                    f"{counts['schedules']} schedule entries, "
                    f"{counts['constraints']} constraints.",
                    "success",
                )
            else:
                flash("No valid records found in CSV.", "error")
        finally:
            os.unlink(tmp_path)

        conn.close()
        return redirect(url_for("upload"))

    @app.route("/upload/template")
    def download_template():
        template_path = os.path.join(os.path.dirname(__file__), "..", "data", "template.csv")
        with open(template_path, "r") as f:
            content = f.read()
        return Response(
            content,
            mimetype="text/csv",
            headers={"Content-Disposition": "attachment; filename=master_schedule_template.csv"},
        )

    @app.route("/settings", methods=["GET", "POST"])
    def settings():
        conn = get_db()

        if request.method == "POST":
            threshold = request.form.get("coverage_threshold", "")
            window = request.form.get("threshold_window_days", "")
            semester = request.form.get("semester_start", "")

            if threshold:
                set_setting(conn, "coverage_threshold", threshold)
            if window:
                set_setting(conn, "threshold_window_days", window)
            if semester:
                set_setting(conn, "semester_start", semester)

            flash("Settings saved.", "success")
            conn.close()
            return redirect(url_for("settings"))

        coverage_threshold = get_setting(conn, "coverage_threshold", str(DEFAULT_COVERAGE_THRESHOLD))
        threshold_window_days = get_setting(conn, "threshold_window_days", str(DEFAULT_THRESHOLD_WINDOW_DAYS))
        semester_start = get_setting(conn, "semester_start", "")

        conn.close()
        return render_template(
            "settings.html",
            active_page="settings",
            coverage_threshold=coverage_threshold,
            threshold_window_days=threshold_window_days,
            semester_start=semester_start,
        )

    return app


def run_web(db_path=None, port=5000):
    """Start the Flask web server."""
    app = create_app(db_path)
    print(f"\n  Coverage Tracker is running at http://localhost:{port}")
    print(f"  Press Ctrl+C to stop.\n")
    app.run(host="0.0.0.0", port=port, debug=True)
