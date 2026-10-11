"""Creates an admin account, or promotes an existing account to admin."""
import getpass
import sys
from django.core.management.base import BaseCommand
from sqlpractice.models import User


def prompt(label, default=""):
    value = input(f"{label}{f' [{default}]' if default else ''}: ").strip()
    return value or default


def ask_password():
    while True:
        pw = getpass.getpass("Password (min 8 characters, hidden as you type): ")
        if len(pw) < 8:
            print("  Too short - use at least 8 characters.")
            continue
        if pw != getpass.getpass("Confirm password: "):
            print("  Passwords don't match - try again.")
            continue
        return pw


class Command(BaseCommand):
    help = "Create an admin account, promote an existing account, or demote an admin"

    def add_arguments(self, parser):
        parser.add_argument("--demote", type=str, help="Email of the account to demote from admin")

    def handle(self, *args, **options):
        demote_email = options.get("demote")
        if demote_email:
            user = User.objects.filter(email=demote_email.strip().lower()).first()
            if not user:
                sys.exit(f"No account with email {demote_email}")
            user.is_admin = False
            user.save(update_fields=["is_admin"])
            self.stdout.write(self.style.SUCCESS(f"{user.email} is no longer an admin."))
            return

        self.stdout.write("\n  Create an admin account for RetailMart SQL Practice\n")
        email = prompt("Admin email").lower()
        if "@" not in email:
            sys.exit("A valid email is required.")

        user = User.objects.filter(email=email).first()
        if user:
            self.stdout.write(f"An account for {email} already exists ({user.name}).")
            if input("Make it an admin? [Y/n]: ").strip().lower() in ("", "y", "yes"):
                user.is_admin = True
                user.is_approved = True
                if input("Also set a new password? [y/N]: ").strip().lower() in ("y", "yes"):
                    user.set_password(ask_password())
                user.save()
                self.stdout.write(self.style.SUCCESS(f"\n  Done - {email} is now an admin. Log in to see student progress.\n"))
            return

        name = prompt("Your name", "Admin")
        user = User.objects.create_user(email=email, password=ask_password(), name=name, is_admin=True, is_approved=True)
        self.stdout.write(self.style.SUCCESS(f"\n  Admin account created for {email}. Start the app with run.bat and log in to see student progress.\n"))
