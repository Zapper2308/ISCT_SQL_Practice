"""Starts the production waitress WSGI server, matching run.bat / Flask waitress behaviour."""
import os
from django.conf import settings
from django.core.management.base import BaseCommand
from waitress import serve

from retailmart.wsgi import application
from sqlpractice.services import get_bank, get_sandbox


class Command(BaseCommand):
    help = "Run the RetailMart SQL Practice application with Waitress (production WSGI server)"

    def add_arguments(self, parser):
        parser.add_argument("--host", default=settings.HOST, help=f"Host to bind (default: {settings.HOST})")
        parser.add_argument("--port", type=int, default=settings.PORT, help=f"Port to bind (default: {settings.PORT})")
        parser.add_argument("--threads", type=int, default=settings.THREADS, help=f"Threads count (default: {settings.THREADS})")

    def handle(self, *args, **options):
        host = options["host"]
        port = options["port"]
        threads = options["threads"]

        bank = get_bank()
        sandbox = get_sandbox()

        self.stdout.write(f"\n  RetailMart SQL Practice: {len(bank.questions)} questions loaded")
        if not sandbox.configured:
            self.stdout.write(self.style.WARNING("  WARNING: PRACTICE_DATABASE_URL is not set in .env - queries can't run yet."))

        display_host = "localhost" if host in ("0.0.0.0", "127.0.0.1") else host
        self.stdout.write(f"  Open http://{display_host}:{port}\n")

        serve(application, host=host, port=port, threads=threads)
