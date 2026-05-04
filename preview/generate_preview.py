#!/usr/bin/env python3
"""Generate standalone HTML preview files from the running Flask app.

Uses Flask's test client to capture each page with realistic sample data,
then saves them as .html files that can be opened directly in a browser.
"""

import os
import sys
import tempfile

# Add parent dir to path so we can import coverage_tracker
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from coverage_tracker.app import create_app
from coverage_tracker.db import get_connection, init_db
from coverage_tracker.scheduler import record_absence, assign_coverage, find_coverage_options


def main():
    preview_dir = os.path.dirname(os.path.abspath(__file__))

    # Create app with a temp database (auto-seeds sample data)
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    db_path = tmp.name
    tmp.close()

    app = create_app(db_path=db_path)
    client = app.test_client()

    # Seed some absences and coverage assignments for realistic data
    conn = get_connection(db_path)
    init_db(conn)

    # Record an absence for Bob Johnson (teacher_id=2) on 2026-03-23 (Monday)
    absence_id = record_absence(conn, teacher_id=2, date="2026-03-23",
                                periods=[1, 2, 3, 4], reason="Sick day")

    # Find coverage options and assign a couple
    if absence_id:
        for period in [1, 2]:
            options = find_coverage_options(conn, date="2026-03-23", period=period,
                                           absent_teacher_id=2)
            if options:
                assign_coverage(conn, absence_id=absence_id,
                                covering_teacher_id=options[0].teacher_id,
                                date="2026-03-23", period=period)

    # Record a second absence for Alice Smith (teacher_id=1) on 2026-03-24
    absence_id2 = record_absence(conn, teacher_id=1, date="2026-03-24",
                                 periods=[1, 2, 3], reason="Personal day")
    conn.close()

    # Pages to capture
    pages = {
        "dashboard.html": "/",
        "teachers.html": "/teachers",
        "absences.html": "/absences",
        "absence_form.html": "/absences/new",
        "history.html": "/history",
        "fairness.html": "/fairness",
        "upload.html": "/upload",
        "settings.html": "/settings",
    }

    # Add absence detail page
    if absence_id:
        pages["absence_detail.html"] = f"/absences/{absence_id}"
    if absence_id2:
        pages["absence_detail_today.html"] = f"/absences/{absence_id2}"

    for filename, url in pages.items():
        response = client.get(url, follow_redirects=True)
        filepath = os.path.join(preview_dir, filename)

        html = response.data.decode("utf-8")

        # Fix relative URLs so CSS/links work as standalone files
        # Replace href="/" with href="dashboard.html" etc.
        html = html.replace('href="/"', 'href="dashboard.html"')
        html = html.replace('href="/teachers"', 'href="teachers.html"')
        html = html.replace('href="/absences/new"', 'href="absence_form.html"')
        html = html.replace('href="/absences"', 'href="absences.html"')
        html = html.replace('href="/history"', 'href="history.html"')
        html = html.replace('href="/fairness"', 'href="fairness.html"')
        html = html.replace('href="/upload"', 'href="upload.html"')
        html = html.replace('href="/settings"', 'href="settings.html"')

        with open(filepath, "w") as f:
            f.write(html)

        print(f"  Saved {filename} ({len(html):,} bytes)")

    # Cleanup temp DB
    os.unlink(db_path)
    print(f"\nDone! Open any .html file in preview/ to see the UI.")


if __name__ == "__main__":
    main()
