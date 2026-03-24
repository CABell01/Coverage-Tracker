"""Database setup and connection management using SQLite."""

import sqlite3
import os
from .config import DEFAULT_DB_PATH


def get_connection(db_path: str = None) -> sqlite3.Connection:
    """Get a database connection with row factory enabled."""
    if db_path is None:
        db_path = DEFAULT_DB_PATH
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    """Create all tables if they don't exist."""
    cursor = conn.cursor()

    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS teachers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            department TEXT DEFAULT '',
            email TEXT DEFAULT '',
            active INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            day_of_week TEXT NOT NULL,
            period INTEGER NOT NULL,
            subject TEXT DEFAULT '',
            room TEXT DEFAULT '',
            is_free INTEGER DEFAULT 0,
            FOREIGN KEY (teacher_id) REFERENCES teachers(id),
            UNIQUE(teacher_id, day_of_week, period)
        );

        CREATE TABLE IF NOT EXISTS constraints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            constraint_type TEXT NOT NULL,
            constraint_value TEXT NOT NULL,
            FOREIGN KEY (teacher_id) REFERENCES teachers(id)
        );

        CREATE TABLE IF NOT EXISTS absences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            periods TEXT NOT NULL,
            reason TEXT DEFAULT '',
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (teacher_id) REFERENCES teachers(id)
        );

        CREATE TABLE IF NOT EXISTS coverage_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            absence_id INTEGER NOT NULL,
            covering_teacher_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            period INTEGER NOT NULL,
            subject TEXT DEFAULT '',
            room TEXT DEFAULT '',
            assigned_at TEXT DEFAULT (datetime('now')),
            status TEXT DEFAULT 'assigned',
            FOREIGN KEY (absence_id) REFERENCES absences(id),
            FOREIGN KEY (covering_teacher_id) REFERENCES teachers(id)
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    """)

    conn.commit()


def get_setting(conn: sqlite3.Connection, key: str, default: str = None) -> str:
    """Retrieve a setting value."""
    row = conn.execute(
        "SELECT value FROM settings WHERE key = ?", (key,)
    ).fetchone()
    return row["value"] if row else default


def set_setting(conn: sqlite3.Connection, key: str, value: str) -> None:
    """Store a setting value."""
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
        (key, value),
    )
    conn.commit()
