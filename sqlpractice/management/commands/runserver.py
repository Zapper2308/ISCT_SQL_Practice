"""Subclasses Django's runserver to default to HOST and PORT from settings / .env."""
import os
from django.conf import settings
from django.core.management.commands.runserver import Command as BaseRunserverCommand

from sqlpractice.services import get_bank, get_sandbox


class Command(BaseRunserverCommand):
    default_port = str(getattr(settings, "PORT", 5000))
    default_addr = getattr(settings, "HOST", "127.0.0.1")

    def inner_run(self, *args, **options):
        # Only print in the main process (or when run without auto-reloader)
        if os.environ.get("RUN_MAIN") != "true":
            bank = get_bank()
            sandbox = get_sandbox()
            self.stdout.write(f"\n  RetailMart SQL Practice: {len(bank.questions)} questions loaded")
            if not sandbox.configured:
                self.stdout.write(self.style.WARNING("  WARNING: PRACTICE_DATABASE_URL is not set in .env - queries can't run yet."))

        return super().inner_run(*args, **options)
