"""Allow running as: python -m coverage_tracker"""

import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Teacher Coverage Scheduler")
    parser.add_argument(
        "--db", default=None,
        help="Path to SQLite database file (default: coverage_tracker.db)",
    )
    parser.add_argument(
        "--web", action="store_true",
        help="Launch the web UI instead of the CLI",
    )
    parser.add_argument(
        "--port", type=int, default=5000,
        help="Port for the web server (default: 5000)",
    )
    args = parser.parse_args()

    if args.web:
        from .app import run_web
        run_web(db_path=args.db, port=args.port)
    else:
        from .cli import main
        main(db_path=args.db)
