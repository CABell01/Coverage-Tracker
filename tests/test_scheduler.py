"""Tests for the scheduling algorithm."""

import os
import tempfile
import unittest
from coverage_tracker.db import get_connection, init_db
from coverage_tracker.csv_loader import save_teachers, save_schedules, save_constraints
from coverage_tracker.scheduler import (
    record_absence, find_coverage_options, assign_coverage,
    cancel_coverage, get_absent_teacher_schedule,
)


class TestScheduler(unittest.TestCase):
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
        """Set up a small school for testing."""
        teachers = [
            {"name": "Alice", "department": "Math", "email": ""},
            {"name": "Bob", "department": "Science", "email": ""},
            {"name": "Carol", "department": "English", "email": ""},
            {"name": "Dan", "department": "History", "email": ""},
        ]
        save_teachers(self.conn, teachers)

        # Monday schedule: Alice teaches P1-P3, free P4
        # Bob: free P1, teaches P2-P3, free P4
        # Carol: teaches P1, free P2-P3, teaches P4
        # Dan: free P1-P2, teaches P3-P4
        schedules = [
            # Alice
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 1, "subject": "Algebra", "room": "101", "is_free": False},
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 2, "subject": "Geometry", "room": "101", "is_free": False},
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 3, "subject": "Algebra", "room": "101", "is_free": False},
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 4, "subject": "", "room": "", "is_free": True},
            # Bob
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 1, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 2, "subject": "Biology", "room": "Lab1", "is_free": False},
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 3, "subject": "Chemistry", "room": "Lab1", "is_free": False},
            {"teacher_name": "Bob", "day_of_week": "Monday", "period": 4, "subject": "", "room": "", "is_free": True},
            # Carol
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 1, "subject": "English 9", "room": "201", "is_free": False},
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 2, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 3, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Carol", "day_of_week": "Monday", "period": 4, "subject": "English 10", "room": "201", "is_free": False},
            # Dan
            {"teacher_name": "Dan", "day_of_week": "Monday", "period": 1, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Dan", "day_of_week": "Monday", "period": 2, "subject": "", "room": "", "is_free": True},
            {"teacher_name": "Dan", "day_of_week": "Monday", "period": 3, "subject": "History", "room": "301", "is_free": False},
            {"teacher_name": "Dan", "day_of_week": "Monday", "period": 4, "subject": "History", "room": "301", "is_free": False},
        ]
        save_schedules(self.conn, schedules)

    def _get_teacher_id(self, name):
        return self.conn.execute("SELECT id FROM teachers WHERE name = ?", (name,)).fetchone()["id"]

    def test_record_absence(self):
        alice_id = self._get_teacher_id("Alice")
        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1, 2, 3])  # Monday
        self.assertIsNotNone(absence_id)

        row = self.conn.execute("SELECT * FROM absences WHERE id = ?", (absence_id,)).fetchone()
        self.assertEqual(row["teacher_id"], alice_id)
        self.assertEqual(row["periods"], "1,2,3")

    def test_find_coverage_options_basic(self):
        """When Alice is absent P1, Bob and Dan are free P1."""
        alice_id = self._get_teacher_id("Alice")
        options = find_coverage_options(self.conn, "2026-03-23", 1, alice_id, "Algebra", "101")
        names = [o.teacher_name for o in options]
        self.assertIn("Bob", names)
        self.assertIn("Dan", names)
        self.assertNotIn("Carol", names)  # Carol teaches P1
        self.assertNotIn("Alice", names)  # Alice is absent

    def test_find_coverage_excludes_absent_teacher(self):
        alice_id = self._get_teacher_id("Alice")
        options = find_coverage_options(self.conn, "2026-03-23", 4, alice_id, "Math", "101")
        names = [o.teacher_name for o in options]
        self.assertNotIn("Alice", names)

    def test_subject_constraint(self):
        """Carol with no_subject=Science should not be offered for Science classes."""
        carol_id = self._get_teacher_id("Carol")
        constraints = [{"teacher_name": "Carol", "constraint_type": "no_subject", "constraint_value": "Biology"}]
        save_constraints(self.conn, constraints)

        bob_id = self._get_teacher_id("Bob")
        # Bob absent P2 (Biology). Carol is free P2 but has no_subject=Biology
        options = find_coverage_options(self.conn, "2026-03-23", 2, bob_id, "Biology", "Lab1")
        names = [o.teacher_name for o in options]
        self.assertNotIn("Carol", names)

    def test_max_per_week_constraint(self):
        """Dan with max_per_week=1 should be excluded after 1 coverage."""
        dan_id = self._get_teacher_id("Dan")
        constraints = [{"teacher_name": "Dan", "constraint_type": "max_per_week", "constraint_value": "1"}]
        save_constraints(self.conn, constraints)

        alice_id = self._get_teacher_id("Alice")
        # First, assign Dan to cover one slot
        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1])
        assign_coverage(self.conn, absence_id, dan_id, "2026-03-23", 1, "Algebra", "101")

        # Now Dan should be excluded from further coverage this week
        options = find_coverage_options(self.conn, "2026-03-23", 2, alice_id, "Geometry", "101")
        names = [o.teacher_name for o in options]
        self.assertNotIn("Dan", names)

    def test_fairness_scoring(self):
        """Teacher with more past coverages should have higher score."""
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")
        dan_id = self._get_teacher_id("Dan")

        # Give Bob several past coverages
        absence_id = record_absence(self.conn, alice_id, "2026-03-16", [1])
        for _ in range(3):
            assign_coverage(self.conn, absence_id, bob_id, "2026-03-16", 1, "Algebra", "101")

        # Now check options for P1 - Dan should rank higher than Bob
        options = find_coverage_options(self.conn, "2026-03-23", 1, alice_id, "Algebra", "101")
        bob_opt = next((o for o in options if o.teacher_name == "Bob"), None)
        dan_opt = next((o for o in options if o.teacher_name == "Dan"), None)

        self.assertIsNotNone(bob_opt)
        self.assertIsNotNone(dan_opt)
        self.assertGreater(bob_opt.score, dan_opt.score)

    def test_already_covering_same_period(self):
        """A teacher already covering a period should not be offered again."""
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")
        carol_id = self._get_teacher_id("Carol")

        # Carol absent P1. Bob covers.
        absence1 = record_absence(self.conn, carol_id, "2026-03-23", [1])
        assign_coverage(self.conn, absence1, bob_id, "2026-03-23", 1, "English 9", "201")

        # Alice also absent P1. Bob should not appear (already covering P1).
        options = find_coverage_options(self.conn, "2026-03-23", 1, alice_id, "Algebra", "101")
        names = [o.teacher_name for o in options]
        self.assertNotIn("Bob", names)

    def test_get_absent_teacher_schedule(self):
        alice_id = self._get_teacher_id("Alice")
        info = get_absent_teacher_schedule(self.conn, alice_id, "2026-03-23", 1)
        self.assertEqual(info["subject"], "Algebra")
        self.assertEqual(info["room"], "101")

    def test_cancel_coverage(self):
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")

        absence_id = record_absence(self.conn, alice_id, "2026-03-23", [1])
        cov_id = assign_coverage(self.conn, absence_id, bob_id, "2026-03-23", 1, "Algebra", "101")

        cancel_coverage(self.conn, cov_id)
        row = self.conn.execute("SELECT status FROM coverage_records WHERE id = ?", (cov_id,)).fetchone()
        self.assertEqual(row["status"], "cancelled")

    def test_flagging_high_coverage(self):
        """Teachers exceeding threshold should be flagged."""
        alice_id = self._get_teacher_id("Alice")
        bob_id = self._get_teacher_id("Bob")

        # Give Bob 5 past coverages (default threshold is 5)
        for i in range(5):
            absence_id = record_absence(self.conn, alice_id, f"2026-03-{16+i:02d}", [1])
            assign_coverage(self.conn, absence_id, bob_id, f"2026-03-{16+i:02d}", 1, "Algebra", "101")

        options = find_coverage_options(self.conn, "2026-03-23", 1, alice_id, "Algebra", "101")
        bob_opt = next((o for o in options if o.teacher_name == "Bob"), None)
        self.assertIsNotNone(bob_opt)
        self.assertTrue(bob_opt.flagged)
        self.assertIn("threshold", bob_opt.flag_reason)


if __name__ == "__main__":
    unittest.main()
