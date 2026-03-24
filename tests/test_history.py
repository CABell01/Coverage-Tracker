"""Tests for coverage history and fairness reporting."""

import os
import tempfile
import unittest
from coverage_tracker.db import get_connection, init_db
from coverage_tracker.csv_loader import save_teachers, save_schedules
from coverage_tracker.scheduler import record_absence, assign_coverage
from coverage_tracker.history import (
    get_teacher_coverage_history, get_fairness_report, get_absences_for_date,
)


class TestHistory(unittest.TestCase):
    def setUp(self):
        self.db_fd, self.db_path = tempfile.mkstemp(suffix=".db")
        self.conn = get_connection(self.db_path)
        init_db(self.conn)
        self._setup_test_data()

    def tearDown(self):
        self.conn.close()
        os.close(self.db_fd)
        os.unlink(self.db_path)

    def _setup_test_data(self):
        teachers = [
            {"name": "Alice", "department": "Math", "email": ""},
            {"name": "Bob", "department": "Science", "email": ""},
            {"name": "Carol", "department": "English", "email": ""},
        ]
        save_teachers(self.conn, teachers)

        schedules = [
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 1, "subject": "Algebra", "room": "101", "is_free": False},
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 2, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 1, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 2, "subject": "Biology", "room": "Lab1", "is_free": False},
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 1, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 2, "subject": "", "room": "", "is_free": True},
        ]
        save_schedules(self.conn, schedules)

    def _get_teacher_id(self, name):
        return self.conn.execute("SELECT id FROM teachers WHERE name = ?", (name,)).fetchone()["id"]

    def test_coverage_history_empty(self):
        records = get_teacher_coverage_history(self.conn)
        self.assertEqual(len(records), 0)

    def test_coverage_history_with_records(self):
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")

        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1])
        assign_coverage(self.conn, absence_id, bob_id, "2026-03-23", 1, "Algebra", "101")

        records = get_teacher_coverage_history(self.conn)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["covering_teacher"], "Bob")
        self.assertEqual(records[0]["absent_teacher"], "Alice")

    def test_coverage_history_filter_by_teacher(self):
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")
        carol_id = self._get_teacher_id("Carol")

        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1])
        assign_coverage(self.conn, absence_id, bob_id, "2026-03-23", 1, "Algebra", "101")
        assign_coverage(self.conn, absence_id, carol_id, "2026-03-23", 1, "Algebra", "101")

        records = get_teacher_coverage_history(self.conn, teacher_id=bob_id)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["covering_teacher"], "Bob")

    def test_fairness_report(self):
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")

        # Bob covers twice
        for date in ["2026-03-16", "2026-03-17"]:
            absence_id = record_absence(self.conn, alice_id, date, [1])
            assign_coverage(self.conn, absence_id, bob_id, date, 1, "Algebra", "101")

        report = get_fairness_report(self.conn)
        self.assertEqual(len(report), 3)  # All 3 teachers

        # Bob should be first (most coverages)
        self.assertEqual(report[0]["name"], "Bob")
        self.assertEqual(report[0]["semester_total"], 2)

    def test_absences_for_date(self):
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")

        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1, 2])
        assign_coverage(self.conn, absence_id, bob_id, "2026-03-23", 1, "Algebra", "101")

        absences = get_absences_for_date(self.conn, "2026-03-23")
        self.assertEqual(len(absences), 1)
        self.assertEqual(absences[0]["teacher_name"], "Alice")
        self.assertEqual(len(absences[0]["periods"]), 2)
        # Period 1 is covered, period 2 is not
        self.assertIsNotNone(absences[0]["period_coverage"][1])
        self.assertIsNone(absences[0]["period_coverage"][2])

    def test_no_absences_for_date(self):
        absences = get_absences_for_date(self.conn, "2026-03-23")
        self.assertEqual(len(absences), 0)


if __name__ == "__main__":
    unittest.main()
