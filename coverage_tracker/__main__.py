"""Allow running as: python -m coverage_tracker"""

import argparse
from .cli import main

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Teacher Coverage Scheduler")
    parser.add_argument(
        "--db", default=None,
        help="Path to SQLite database file (default: coverage_tracker.db)",
    )
    args = parser.parse_args()
    main(db_path=args.db)
