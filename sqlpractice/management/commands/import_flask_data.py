"""Imports existing users, progress, and password reset requests from a legacy Flask SQLite DB."""
import sqlite3
from pathlib import Path
from datetime import datetime, timezone as dt_timezone

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from sqlpractice.models import PasswordResetRequest, Progress, User


def parse_dt(val):
    if not val:
        return None
    dt = parse_datetime(val)
    if dt is None:
        try:
            dt = datetime.fromisoformat(val)
        except Exception:
            return None
    if timezone.is_naive(dt):
        dt = timezone.make_aware(dt, dt_timezone.utc)
    return dt


class Command(BaseCommand):
    help = "Import data from legacy Flask instance/sqlpractice.db into Django"

    def add_arguments(self, parser):
        parser.add_argument(
            "--db",
            default=str(settings.BASE_DIR / "instance" / "sqlpractice.db"),
            help="Path to legacy sqlite DB (default: instance/sqlpractice.db)",
        )

    def handle(self, *args, **options):
        db_path = Path(options["db"])
        if not db_path.exists():
            self.stdout.write(self.style.WARNING(f"File {db_path} does not exist. Skipping import."))
            return

        conn = sqlite3.connect(db_path)
        c = conn.cursor()

        # Check existing tables
        tables = [r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
        if "users" not in tables:
            self.stdout.write(self.style.WARNING("No users table found in SQLite DB."))
            return

        self.stdout.write(f"Importing data from {db_path}...")

        # 1. Users
        user_id_map = {}
        c.execute("SELECT id, name, email, password_hash, is_admin, created_at FROM users")
        user_rows = c.fetchall()

        imported_users = 0
        for uid, name, email, password_hash, is_admin, created_at in user_rows:
            email = email.strip().lower()
            u = User.objects.filter(email=email).first()
            if not u:
                u = User(
                    name=name,
                    email=email,
                    is_admin=bool(is_admin),
                    created_at=parse_dt(created_at) or timezone.now(),
                )
                # Ensure werkzeug prefix so WerkzeugPasswordHasher handles it
                if not password_hash.startswith("werkzeug$"):
                    u.password = f"werkzeug${password_hash}"
                else:
                    u.password = password_hash
                u.save()
                imported_users += 1
            user_id_map[uid] = u

        self.stdout.write(self.style.SUCCESS(f"Imported/verified {len(user_rows)} users ({imported_users} new)."))

        # 2. Progress
        if "progress" in tables:
            c.execute("""
                SELECT id, user_id, question_id, difficulty, topic_slug, status,
                       solved_method, attempts, answer_revealed, submissions,
                       last_query, solved_at, updated_at
                FROM progress
            """)
            prog_rows = c.fetchall()
            imported_prog = 0
            for row in prog_rows:
                (pid, uid, qid, diff, topic_slug, status, solved_method,
                 attempts, answer_revealed, submissions, last_query, solved_at, updated_at) = row
                user = user_id_map.get(uid)
                if not user:
                    continue

                prog, created = Progress.objects.get_or_create(
                    user=user,
                    question_id=qid,
                    defaults={
                        "difficulty": diff,
                        "topic_slug": topic_slug,
                        "status": status,
                        "solved_method": solved_method,
                        "attempts": attempts or 0,
                        "answer_revealed": bool(answer_revealed),
                        "submissions": submissions or 0,
                        "last_query": last_query or "",
                        "solved_at": parse_dt(solved_at),
                    }
                )
                if created:
                    imported_prog += 1
            self.stdout.write(self.style.SUCCESS(f"Imported {imported_prog} progress entries ({len(prog_rows)} total in legacy DB)."))

        # 3. Password reset requests
        if "password_reset_requests" in tables:
            c.execute("SELECT id, user_id, created_at, emailed, resolved_at FROM password_reset_requests")
            reset_rows = c.fetchall()
            imported_resets = 0
            for rid, uid, created_at, emailed, resolved_at in reset_rows:
                user = user_id_map.get(uid)
                if not user:
                    continue
                req, created = PasswordResetRequest.objects.get_or_create(
                    user=user,
                    created_at=parse_dt(created_at) or timezone.now(),
                    defaults={
                        "emailed": bool(emailed),
                        "resolved_at": parse_dt(resolved_at),
                    }
                )
                if created:
                    imported_resets += 1
            self.stdout.write(self.style.SUCCESS(f"Imported {imported_resets} password reset requests."))

        conn.close()
        self.stdout.write(self.style.SUCCESS("Import completed successfully!"))
