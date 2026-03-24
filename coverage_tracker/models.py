"""Data models for the coverage tracker."""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Teacher:
    name: str
    department: str = ""
    email: str = ""
    id: Optional[int] = None
    active: bool = True


@dataclass
class Schedule:
    teacher_name: str
    day_of_week: str
    period: int
    subject: str = ""
    room: str = ""
    is_free: bool = False
    id: Optional[int] = None
    teacher_id: Optional[int] = None


@dataclass
class Constraint:
    teacher_name: str
    constraint_type: str
    constraint_value: str
    id: Optional[int] = None
    teacher_id: Optional[int] = None


@dataclass
class Absence:
    teacher_id: int
    date: str
    periods: list = field(default_factory=list)
    reason: str = ""
    id: Optional[int] = None


@dataclass
class CoverageRecord:
    absence_id: int
    covering_teacher_id: int
    date: str
    period: int
    subject: str = ""
    room: str = ""
    status: str = "assigned"
    id: Optional[int] = None


@dataclass
class CoverageOption:
    teacher_id: int
    teacher_name: str
    department: str
    score: float
    coverages_this_semester: int
    coverages_last_14_days: int
    coverages_today: int
    flagged: bool = False
    flag_reason: str = ""
