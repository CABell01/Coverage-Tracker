"""Application-wide configuration and defaults."""

# Default database path
DEFAULT_DB_PATH = "coverage_tracker.db"

# Period range (inclusive)
MIN_PERIOD = 1
MAX_PERIOD = 4

VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

# Fairness scoring weights (lower score = higher priority for coverage)
WEIGHT_TOTAL_SEMESTER = 1.0      # Long-term fairness
WEIGHT_RECENT_14_DAYS = 2.0     # Recency penalty
WEIGHT_SAME_DAY = 5.0           # Strongly avoid double-coverage same day

# Coverage threshold: flag teachers who exceed this many coverages per month
DEFAULT_COVERAGE_THRESHOLD = 5
DEFAULT_THRESHOLD_WINDOW_DAYS = 30

# How many top candidates to display
DEFAULT_TOP_CANDIDATES = 5
