"""Tests for CSV loading and validation."""

import os
import tempfile
import unittest
from coverage_tracker.db import get_connection, init_db
from coverage_tracker.csv_loader import (
    load_teachers_csv, load_schedules_csv, load_constraints_csv,
    save_teachers, save_schedules, save_constraints,
)


class TestCSVLoader(unittest.TestCase):
    def setUp(self):
        self.db_fd, self.db_path = tempfile.mkstemp(suffix=".db")
        self.conn = get_connection(self.db_path)
        init_db(self.conn)
        self.tmpfiles = []

    def tearDown(self):
        self.conn.close()
        os.close(self.db_fd)
        os.unlink(self.db_path)
        for f in self.tmpfiles:
            if os.path.exists(f):
                os.unlink(f)

    def _write_csv(self, content):
        fd, path = tempfile.mkstemp(suffix=".csv")
        os.close(fd)
        with open(path, "w") as f:
            f.write(content)
        self.tmpfiles.append(path)
        return path

    def test_load_teachers_valid(self):
        path = self._write_csv("name,department,email\nAlice,Math,a@test.com\nBob,Science,b@test.com\n")
        records, errors = load_teachers_csv(path)
        self.assertEqual(len(records), 2)
        self.assertEqual(len(errors), 0)
        self.assertEqual(records[0]["name"], "Alice")

    def test_load_teachers_duplicate_names(self):
        path = self._write_csv("name,department,email\nAlice,Math,a@test.com\nAlice,Science,a2@test.com\n")
        records, errors = load_teachers_csv(path)
        self.assertEqual(len(records), 1)
        self.assertEqual(len(errors), 1)
        self.assertIn("duplicate", errors[0])

    def test_load_teachers_missing_column(self):
        path = self._write_csv("department,email\nMath,a@test.com\n")
        records, errors = load_teachers_csv(path)
        self.assertEqual(len(records), 0)
        self.assertIn("name", errors[0])

    def test_load_teachers_file_not_found(self):
        records, errors = load_teachers_csv("/nonexistent/file.csv")
        self.assertEqual(len(records), 0)
        self.assertEqual(len(errors), 1)

    def test_load_schedules_valid(self):
        path = self._write_csv(
            "teacher_name,day_of_week,period,subject,room,is_free\n"
            "Alice,Monday,1,Math,Room 1,0\n"
            "Alice,Monday,2,,,1\n"
        )
        records, errors = load_schedules_csv(path)
        self.assertEqual(len(records), 2)
        self.assertEqual(len(errors), 0)
        self.assertFalse(records[0]["is_free"])
        self.assertTrue(records[1]["is_free"])

    def test_load_schedules_invalid_day(self):
        path = self._write_csv(
            "teacher_name,day_of_week,period,subject,room,is_free\n"
            "Alice,Funday,1,Math,Room 1,0\n"
        )
        records, errors = load_schedules_csv(path)
        self.assertEqual(len(records), 0)
        self.assertEqual(len(errors), 1)

    def test_load_schedules_invalid_period(self):
        path = self._write_csv(
            "teacher_name,day_of_week,period,subject,room,is_free\n"
            "Alice,Monday,99,Math,Room 1,0\n"
        )
        records, errors = load_schedules_csv(path)
        self.assertEqual(len(records), 0)
        self.assertEqual(len(errors), 1)

    def test_load_constraints_valid(self):
        path = self._write_csv(
            "teacher_name,constraint_type,constraint_value\n"
            "Alice,no_subject,Science\n"
            "Bob,max_per_week,3\n"
        )
        records, errors = load_constraints_csv(path)
        self.assertEqual(len(records), 2)
        self.assertEqual(len(errors), 0)

    def test_load_constraints_invalid_type(self):
        path = self._write_csv(
            "teacher_name,constraint_type,constraint_value\n"
            "Alice,invalid_type,value\n"
        )
        records, errors = load_constraints_csv(path)
        self.assertEqual(len(records), 0)
        self.assertEqual(len(errors), 1)

    def test_save_teachers(self):
        records = [
            {"name": "Alice", "department": "Math", "email": "a@test.com"},
            {"name": "Bob", "department": "Science", "email": "b@test.com"},
        ]
        count, errors = save_teachers(self.conn, records)
        self.assertEqual(count, 2)
        self.assertEqual(len(errors), 0)

        # Verify in DB
        rows = self.conn.execute("SELECT * FROM teachers").fetchall()
        self.assertEqual(len(rows), 2)

    def test_save_teachers_upsert(self):
        records = [{"name": "Alice", "department": "Math", "email": "a@test.com"}]
        save_teachers(self.conn, records)

        records = [{"name": "Alice", "department": "Science", "email": "new@test.com"}]
        save_teachers(self.conn, records)

        rows = self.conn.execute("SELECT * FROM teachers").fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["department"], "Science")

    def test_save_schedules(self):
        save_teachers(self.conn, [{"name": "Alice", "department": "Math", "email": ""}])
        records = [
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 1,
             "subject": "Math", "room": "101", "is_free": False},
            {"teacher_name": "Alice", "day_of_week": "Monday", "period": 2,
             "subject": "", "room": "", "is_free": True},
        ]
        count, errors = save_schedules(self.conn, records)
        self.assertEqual(count, 2)
        self.assertEqual(len(errors), 0)

    def test_save_schedules_unknown_teacher(self):
        records = [
            {"teacher_name": "Unknown", "day_of_week": "Monday", "period": 1,
             "subject": "Math", "room": "101", "is_free": False},
        ]
        count, errors = save_schedules(self.conn, records)
        self.assertEqual(count, 0)
        self.assertEqual(len(errors), 1)


if __name__ == "__main__":
    unittest.main()
