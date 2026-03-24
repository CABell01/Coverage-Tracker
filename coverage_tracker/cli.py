"""Command-line interface for the Teacher Coverage Scheduler."""

import os
import sys
from datetime import datetime
from .db import get_connection, init_db, get_setting, set_setting
from .csv_loader import (
    load_teachers_csv, load_schedules_csv, load_constraints_csv,
    save_teachers, save_schedules, save_constraints,
)
from .scheduler import (
    record_absence, get_absent_teacher_schedule,
    find_coverage_options, assign_coverage, cancel_coverage,
)
from .history import (
    get_teacher_coverage_history, get_fairness_report, get_absences_for_date,
)
from .config import DEFAULT_TOP_CANDIDATES


BANNER = """
╔══════════════════════════════════════════╗
║    Teacher Coverage Scheduler v1.0       ║
╚══════════════════════════════════════════╝
"""

MENU = """
  1. Record an absence
  2. View/assign coverage for today
  3. View coverage history
  4. View teacher fairness report
  5. Load teachers from CSV
  6. Load schedules from CSV
  7. Load constraints from CSV
  8. View all teachers
  9. Settings
  0. Exit
"""


def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")


def pause():
    input("\nPress Enter to continue...")


def search_teacher(conn, query: str) -> list:
    """Search teachers by substring match on name."""
    return conn.execute(
        "SELECT id, name, department FROM teachers WHERE active = 1 AND name LIKE ?",
        (f"%{query}%",),
    ).fetchall()


def prompt_teacher(conn) -> tuple:
    """Prompt user to select a teacher. Returns (id, name) or (None, None)."""
    while True:
        query = input("Enter teacher name (or part of name): ").strip()
        if not query:
            return None, None

        matches = search_teacher(conn, query)
        if not matches:
            print(f"  No teachers found matching '{query}'. Try again or press Enter to cancel.")
            continue

        if len(matches) == 1:
            t = matches[0]
            confirm = input(f"  Found: {t['name']} ({t['department']}). Correct? [Y/n]: ").strip()
            if confirm.lower() != "n":
                return t["id"], t["name"]
            continue

        print(f"  Found {len(matches)} matches:")
        for i, t in enumerate(matches, 1):
            print(f"    {i}. {t['name']} ({t['department']})")
        print(f"    0. Cancel")

        choice = input("  Select number: ").strip()
        try:
            idx = int(choice)
            if idx == 0:
                return None, None
            if 1 <= idx <= len(matches):
                t = matches[idx - 1]
                return t["id"], t["name"]
        except ValueError:
            pass
        print("  Invalid selection.")


def prompt_date(label: str = "Date") -> str:
    """Prompt for a date, default is today."""
    today = datetime.now().strftime("%Y-%m-%d")
    date_str = input(f"{label} [YYYY-MM-DD, default={today}]: ").strip()
    if not date_str:
        return today
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
        return date_str
    except ValueError:
        print("  Invalid date format. Using today.")
        return today


def prompt_periods() -> list:
    """Prompt for periods. Returns list of ints."""
    periods_str = input("Periods (comma-separated, e.g. 1,2,3 or 'all' for 1-8): ").strip()
    if periods_str.lower() == "all":
        return list(range(1, 9))
    try:
        periods = [int(p.strip()) for p in periods_str.split(",") if p.strip()]
        return sorted(set(periods))
    except ValueError:
        print("  Invalid input. Please enter numbers separated by commas.")
        return []


def display_coverage_options(options: list, limit: int = None):
    """Display ranked coverage options."""
    if not options:
        print("  No available teachers found for this slot.")
        return

    if limit is None:
        limit = DEFAULT_TOP_CANDIDATES

    shown = options[:limit]
    print(f"\n  {'#':<4} {'Teacher':<25} {'Dept':<15} {'Score':<8} {'Semester':<10} {'Recent':<9} {'Today':<7} {'Flag'}")
    print(f"  {'─'*4} {'─'*25} {'─'*15} {'─'*8} {'─'*10} {'─'*9} {'─'*7} {'─'*20}")

    for i, opt in enumerate(shown, 1):
        flag = "[!] " + opt.flag_reason if opt.flagged else ""
        print(
            f"  {i:<4} {opt.teacher_name:<25} {opt.department:<15} "
            f"{opt.score:<8.1f} {opt.coverages_this_semester:<10} "
            f"{opt.coverages_last_14_days:<9} {opt.coverages_today:<7} {flag}"
        )

    if len(options) > limit:
        print(f"\n  ... and {len(options) - limit} more available teachers")


def handle_record_absence(conn):
    """Menu option 1: Record an absence and generate coverage options."""
    print("\n── Record an Absence ──\n")

    teacher_id, teacher_name = prompt_teacher(conn)
    if not teacher_id:
        return

    date = prompt_date()
    periods = prompt_periods()
    if not periods:
        return

    reason = input("Reason (optional): ").strip()

    # Record the absence
    absence_id = record_absence(conn, teacher_id, date, periods, reason)
    print(f"\n  Absence recorded for {teacher_name} on {date}, periods {periods}")

    # Generate coverage options for each period
    for period in periods:
        class_info = get_absent_teacher_schedule(conn, teacher_id, date, period)
        subject = class_info["subject"]
        room = class_info["room"]

        if not subject:
            print(f"\n  Period {period}: Free period (no coverage needed)")
            continue

        print(f"\n  ── Period {period}: {subject} in {room} ──")
        options = find_coverage_options(conn, date, period, teacher_id, subject, room)
        display_coverage_options(options)

        if options:
            choice = input("\n  Assign teacher (enter # or 's' to skip): ").strip()
            if choice.lower() == "s" or not choice:
                print("  Skipped.")
                continue
            try:
                idx = int(choice)
                if 1 <= idx <= len(options):
                    selected = options[idx - 1]
                    assign_coverage(
                        conn, absence_id, selected.teacher_id,
                        date, period, subject, room,
                    )
                    print(f"  Assigned: {selected.teacher_name} will cover Period {period}")
                else:
                    print("  Invalid selection. Skipped.")
            except ValueError:
                print("  Invalid input. Skipped.")


def handle_view_today(conn):
    """Menu option 2: View and assign coverage for today."""
    print("\n── Today's Coverage ──\n")

    date = prompt_date("View date")
    absences = get_absences_for_date(conn, date)

    if not absences:
        print(f"  No absences recorded for {date}.")
        return

    for ab in absences:
        print(f"\n  {ab['teacher_name']} - {ab['reason'] or 'No reason given'}")
        for period in ab["periods"]:
            cov = ab["period_coverage"].get(period)
            if cov:
                print(f"    Period {period}: Covered by {cov['covering_teacher']} [{cov['status']}]")
            else:
                class_info = get_absent_teacher_schedule(conn, ab["teacher_id"], date, period)
                if class_info["subject"]:
                    print(f"    Period {period}: {class_info['subject']} in {class_info['room']} - UNCOVERED")
                else:
                    print(f"    Period {period}: Free period")

    # Offer to assign uncovered slots
    assign = input("\nAssign uncovered slots? [y/N]: ").strip()
    if assign.lower() != "y":
        return

    for ab in absences:
        for period in ab["periods"]:
            cov = ab["period_coverage"].get(period)
            if cov is not None:
                continue

            class_info = get_absent_teacher_schedule(conn, ab["teacher_id"], date, period)
            if not class_info["subject"]:
                continue

            print(f"\n  {ab['teacher_name']} - Period {period}: {class_info['subject']} in {class_info['room']}")
            options = find_coverage_options(
                conn, date, period, ab["teacher_id"],
                class_info["subject"], class_info["room"],
            )
            display_coverage_options(options)

            if options:
                choice = input("  Assign teacher (enter # or 's' to skip): ").strip()
                if choice.lower() == "s" or not choice:
                    continue
                try:
                    idx = int(choice)
                    if 1 <= idx <= len(options):
                        selected = options[idx - 1]
                        assign_coverage(
                            conn, ab["absence_id"], selected.teacher_id,
                            date, period, class_info["subject"], class_info["room"],
                        )
                        print(f"  Assigned: {selected.teacher_name}")
                except ValueError:
                    print("  Invalid input. Skipped.")


def handle_coverage_history(conn):
    """Menu option 3: View coverage history."""
    print("\n── Coverage History ──\n")

    print("  Filter by:")
    print("  1. All records")
    print("  2. Specific teacher")
    print("  3. Date range")
    choice = input("  Select [1-3]: ").strip()

    teacher_id = None
    start_date = None
    end_date = None

    if choice == "2":
        teacher_id, _ = prompt_teacher(conn)
        if not teacher_id:
            return
    elif choice == "3":
        start_date = prompt_date("Start date")
        end_date = prompt_date("End date")

    records = get_teacher_coverage_history(conn, teacher_id, start_date, end_date)

    if not records:
        print("\n  No coverage records found.")
        return

    print(f"\n  {'Date':<12} {'Period':<8} {'Covering Teacher':<25} {'For (Absent)':<25} {'Subject':<15} {'Status'}")
    print(f"  {'─'*12} {'─'*8} {'─'*25} {'─'*25} {'─'*15} {'─'*10}")

    for r in records:
        print(
            f"  {r['date']:<12} {r['period']:<8} {r['covering_teacher']:<25} "
            f"{r['absent_teacher']:<25} {r['subject']:<15} {r['status']}"
        )

    print(f"\n  Total records: {len(records)}")


def handle_fairness_report(conn):
    """Menu option 4: View teacher fairness report."""
    print("\n── Teacher Fairness Report ──\n")

    report = get_fairness_report(conn)

    if not report:
        print("  No teachers in the system.")
        return

    print(f"  {'Teacher':<25} {'Dept':<15} {'Semester':<10} {'14 Days':<9} {'Today':<7} {'Flag'}")
    print(f"  {'─'*25} {'─'*15} {'─'*10} {'─'*9} {'─'*7} {'─'*30}")

    for r in report:
        flag = "[!] " + r["flag_reason"] if r["flagged"] else ""
        print(
            f"  {r['name']:<25} {r['department']:<15} "
            f"{r['semester_total']:<10} {r['last_14_days']:<9} "
            f"{r['today']:<7} {flag}"
        )

    # Summary stats
    totals = [r["semester_total"] for r in report]
    if totals:
        avg = sum(totals) / len(totals)
        flagged_count = sum(1 for r in report if r["flagged"])
        print(f"\n  Average coverages per teacher: {avg:.1f}")
        print(f"  Teachers flagged for high load: {flagged_count}")


def handle_load_teachers(conn):
    """Menu option 5: Load teachers from CSV."""
    print("\n── Load Teachers from CSV ──\n")
    filepath = input("Enter CSV file path: ").strip()
    if not filepath:
        return

    records, errors = load_teachers_csv(filepath)

    if errors:
        print("\n  Validation errors:")
        for e in errors:
            print(f"    - {e}")

    if not records:
        print("  No valid records to load.")
        return

    print(f"\n  Found {len(records)} teachers to load:")
    for r in records[:10]:
        print(f"    - {r['name']} ({r['department']})")
    if len(records) > 10:
        print(f"    ... and {len(records) - 10} more")

    confirm = input("\n  Proceed? [y/N]: ").strip()
    if confirm.lower() != "y":
        print("  Cancelled.")
        return

    count, save_errors = save_teachers(conn, records)
    if save_errors:
        for e in save_errors:
            print(f"    - {e}")
    print(f"  Loaded {count} teachers successfully.")


def handle_load_schedules(conn):
    """Menu option 6: Load schedules from CSV."""
    print("\n── Load Schedules from CSV ──\n")
    filepath = input("Enter CSV file path: ").strip()
    if not filepath:
        return

    records, errors = load_schedules_csv(filepath)

    if errors:
        print("\n  Validation errors:")
        for e in errors:
            print(f"    - {e}")

    if not records:
        print("  No valid records to load.")
        return

    teacher_names = set(r["teacher_name"] for r in records)
    print(f"\n  Found {len(records)} schedule entries for {len(teacher_names)} teachers.")
    print("  This will REPLACE existing schedules for these teachers.")

    confirm = input("\n  Proceed? [y/N]: ").strip()
    if confirm.lower() != "y":
        print("  Cancelled.")
        return

    count, save_errors = save_schedules(conn, records)
    if save_errors:
        for e in save_errors:
            print(f"    - {e}")
    print(f"  Loaded {count} schedule entries successfully.")


def handle_load_constraints(conn):
    """Menu option 7: Load constraints from CSV."""
    print("\n── Load Constraints from CSV ──\n")
    filepath = input("Enter CSV file path: ").strip()
    if not filepath:
        return

    records, errors = load_constraints_csv(filepath)

    if errors:
        print("\n  Validation errors:")
        for e in errors:
            print(f"    - {e}")

    if not records:
        print("  No valid records to load.")
        return

    teacher_names = set(r["teacher_name"] for r in records)
    print(f"\n  Found {len(records)} constraints for {len(teacher_names)} teachers.")
    print("  This will REPLACE existing constraints for these teachers.")

    confirm = input("\n  Proceed? [y/N]: ").strip()
    if confirm.lower() != "y":
        print("  Cancelled.")
        return

    count, save_errors = save_constraints(conn, records)
    if save_errors:
        for e in save_errors:
            print(f"    - {e}")
    print(f"  Loaded {count} constraints successfully.")


def handle_view_teachers(conn):
    """Menu option 8: View all teachers."""
    print("\n── All Teachers ──\n")

    teachers = conn.execute(
        "SELECT id, name, department, email, active FROM teachers ORDER BY name"
    ).fetchall()

    if not teachers:
        print("  No teachers in the system. Load teachers from CSV first.")
        return

    print(f"  {'ID':<5} {'Name':<25} {'Department':<15} {'Email':<30} {'Active'}")
    print(f"  {'─'*5} {'─'*25} {'─'*15} {'─'*30} {'─'*6}")

    for t in teachers:
        status = "Yes" if t["active"] else "No"
        print(f"  {t['id']:<5} {t['name']:<25} {t['department']:<15} {t['email']:<30} {status}")

    print(f"\n  Total: {len(teachers)} teachers")


def handle_settings(conn):
    """Menu option 9: View and modify settings."""
    print("\n── Settings ──\n")

    settings = {
        "coverage_threshold": ("Coverage threshold (per window)", "5"),
        "threshold_window_days": ("Threshold window (days)", "30"),
        "semester_start": ("Semester start date", ""),
    }

    print("  Current settings:")
    for key, (label, default) in settings.items():
        val = get_setting(conn, key, default)
        print(f"    {label}: {val}")

    print("\n  Options:")
    keys = list(settings.keys())
    for i, key in enumerate(keys, 1):
        print(f"    {i}. Change {settings[key][0]}")
    print(f"    0. Back")

    choice = input("\n  Select [0-3]: ").strip()
    try:
        idx = int(choice)
        if idx == 0:
            return
        if 1 <= idx <= len(keys):
            key = keys[idx - 1]
            label = settings[key][0]
            current = get_setting(conn, key, settings[key][1])
            new_val = input(f"  New value for {label} [current: {current}]: ").strip()
            if new_val:
                set_setting(conn, key, new_val)
                print(f"  Updated {label} to: {new_val}")
    except ValueError:
        print("  Invalid input.")


def main(db_path: str = None):
    """Main entry point for the CLI."""
    conn = get_connection(db_path)
    init_db(conn)

    clear_screen()
    print(BANNER)

    while True:
        print(MENU)
        choice = input("Select an option [0-9]: ").strip()

        try:
            if choice == "1":
                handle_record_absence(conn)
            elif choice == "2":
                handle_view_today(conn)
            elif choice == "3":
                handle_coverage_history(conn)
            elif choice == "4":
                handle_fairness_report(conn)
            elif choice == "5":
                handle_load_teachers(conn)
            elif choice == "6":
                handle_load_schedules(conn)
            elif choice == "7":
                handle_load_constraints(conn)
            elif choice == "8":
                handle_view_teachers(conn)
            elif choice == "9":
                handle_settings(conn)
            elif choice == "0":
                print("\nGoodbye!")
                conn.close()
                sys.exit(0)
            else:
                print("  Invalid option. Please try again.")
        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            conn.close()
            sys.exit(0)
        except Exception as e:
            print(f"\n  Error: {e}")

        pause()
