"""Tests for database setup."""

import sqlite3
import unittest
import os
import tempfile
from coverage_tracker.db import get_connection, init_db, get_setting, set_setting


class TestDatabase(unittest.TestCase):
    def setUp(self):
        self.db_fd, self.db_path = tempfile.mkstemp(suffix=".db")
        self.conn = get_connection(self.db_path)
        init_db(self.conn)

    def tearDown(self):
        self.conn.close()
        os.close(self.db_fd)
        os.unlink(self.db_path)

    def test_tables_created(self):
        tables = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
        table_names = [t["name"] for t in tables]
        for expected in ["teachers", "schedules", "constraints", "absences", "coverage_records", "settings"]:
            self.assertIn(expected, table_names)

    def test_init_idempotent(self):
        # Running init_db again should not error
        init_db(self.conn)
        tables = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
        self.assertTrue(len(tables) >= 6)

    def test_settings(self):
        self.assertIsNone(get_setting(self.conn, "nonexistent"))
        self.assertEqual(get_setting(self.conn, "nonexistent", "default"), "default")

        set_setting(self.conn, "test_key", "test_value")
        self.assertEqual(get_setting(self.conn, "test_key"), "test_value")

        set_setting(self.conn, "test_key", "updated_value")
        self.assertEqual(get_setting(self.conn, "test_key"), "updated_value")


if __name__ == "__main__":
    unittest.main()
