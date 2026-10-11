"""Django settings for RetailMart SQL Practice.

Everything configurable lives in `.env` (see README.md); this file only maps those values onto Django.
"""
import os
import secrets
from pathlib import Path
from urllib.parse import parse_qsl, unquote, urlparse

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def env(name, default=""):
    return os.getenv(name, default)


def env_bool(name, default):
    return env(name, str(default)).strip().lower() in ("1", "true", "yes", "on")


def env_list(name, default=""):
    return [s.strip() for s in env(name, default).split(",") if s.strip()]


def database_from_url(url):
    """Turns APP_DATABASE_URL (sqlite:///file.db or postgresql://...) into a DATABASES entry.

    Relative SQLite paths are stored in the `instance/` folder, like the original Flask app did.
    """
    if not url or url.startswith("sqlite"):
        path = url.split(":///", 1)[1] if ":///" in url else "retailmart.sqlite3"
        path = Path(path)
        if not path.is_absolute():
            path = BASE_DIR / "instance" / path
        path.parent.mkdir(parents=True, exist_ok=True)
        return {"ENGINE": "django.db.backends.sqlite3", "NAME": str(path)}

    parsed = urlparse(url)
    if not parsed.scheme.split("+")[0] in ("postgres", "postgresql"):
        raise ValueError(f"Unsupported APP_DATABASE_URL scheme: {parsed.scheme}")
    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": unquote(parsed.path.lstrip("/")) or "postgres",
        "USER": unquote(parsed.username or ""),
        "PASSWORD": unquote(parsed.password or ""),
        "HOST": parsed.hostname or "",
        "PORT": str(parsed.port or ""),
        "OPTIONS": dict(parse_qsl(parsed.query)),
        "CONN_MAX_AGE": 60,
        "CONN_HEALTH_CHECKS": True,     # equivalent of SQLAlchemy's pool_pre_ping
    }


# ----------------------------------------------------------------- core

# FLASK_SECRET_KEY / FLASK_DEBUG are still accepted so an existing .env keeps working.
SECRET_KEY = env("DJANGO_SECRET_KEY") or env("FLASK_SECRET_KEY") or secrets.token_hex(32)
DEBUG = env_bool("DEBUG", env_bool("FLASK_DEBUG", False))
ALLOWED_HOSTS = env_list("ALLOWED_HOSTS", "*")
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.humanize",
    "sqlpractice",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "retailmart.urls"
WSGI_APPLICATION = "retailmart.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "sqlpractice.context_processors.globals",
            ],
        },
    },
]

DATABASES = {"default": database_from_url(env("APP_DATABASE_URL", "sqlite:///retailmart.sqlite3"))}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ----------------------------------------------------------------- auth

AUTH_USER_MODEL = "sqlpractice.User"
LOGIN_URL = "login"
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
    # Verifies hashes imported from the Flask app; they're upgraded to PBKDF2 on the next login.
    "sqlpractice.hashers.WerkzeugPasswordHasher",
]

RESET_LINK_HOURS = int(env("RESET_LINK_HOURS", "24"))
PASSWORD_RESET_TIMEOUT = RESET_LINK_HOURS * 3600

SESSION_COOKIE_AGE = 14 * 24 * 3600
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
SESSION_COOKIE_SECURE = env_bool("SESSION_COOKIE_SECURE", False)
CSRF_COOKIE_SECURE = env_bool("CSRF_COOKIE_SECURE", False)
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# The front-end JS sends the token in an "X-CSRF-Token" header (read from <meta name="csrf-token">).
CSRF_HEADER_NAME = "HTTP_X_CSRF_TOKEN"
CSRF_FAILURE_VIEW = "sqlpractice.views.csrf_failure"

# ----------------------------------------------------------------- i18n / time

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"      # stored as UTC; templates show times in the server's local timezone
USE_I18N = False
USE_TZ = True

# ----------------------------------------------------------------- static files (served by WhiteNoise)

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]
WHITENOISE_USE_FINDERS = True          # serve straight from static/ - no collectstatic needed
WHITENOISE_AUTOREFRESH = DEBUG

# ----------------------------------------------------------------- messages

from django.contrib.messages import constants as message_constants  # noqa: E402

MESSAGE_TAGS = {message_constants.INFO: "message"}

# ----------------------------------------------------------------- email (password reset links)

EMAIL_HOST = env("SMTP_HOST")
EMAIL_PORT = int(env("SMTP_PORT", "587") or 587)
EMAIL_HOST_USER = env("SMTP_USER")
EMAIL_HOST_PASSWORD = env("SMTP_PASSWORD")
EMAIL_USE_SSL = EMAIL_PORT == 465
EMAIL_USE_TLS = env_bool("SMTP_TLS", True) and not EMAIL_USE_SSL
EMAIL_TIMEOUT = 20
DEFAULT_FROM_EMAIL = env("SMTP_FROM") or EMAIL_HOST_USER
EMAIL_ENABLED = bool(EMAIL_HOST and DEFAULT_FROM_EMAIL)
APP_BASE_URL = env("APP_BASE_URL").rstrip("/")

# ----------------------------------------------------------------- practice app

PRACTICE_DIR = BASE_DIR / env("PRACTICE_DIR", "Practice")
PRACTICE_DATABASE_URL = env("PRACTICE_DATABASE_URL")
QUERY_TIMEOUT_SECONDS = float(env("QUERY_TIMEOUT_SECONDS", "15"))
MAX_RESULT_ROWS = int(env("MAX_RESULT_ROWS", "0"))
DB_POOL_MAX = int(env("DB_POOL_MAX", "10"))
ALLOW_ANSWER_REVEAL = env_bool("ALLOW_ANSWER_REVEAL", True)

LLM_BASE_URL = env("LLM_BASE_URL")
LLM_API_KEY = env("LLM_API_KEY")
LLM_MODEL = env("LLM_MODEL")

GEMINI_API_KEY = env("GEMINI_API_KEY") or env("GOOGLE_API_KEY")
GEMINI_MODEL = env("GEMINI_MODEL", "gemini-3.5-flash-lite")

# Supabase / Postgres internals hidden from the schema browser.
SCHEMA_EXCLUDE = {
    "information_schema", "auth", "storage", "realtime", "_realtime", "extensions", "graphql",
    "graphql_public", "pgbouncer", "vault", "net", "supabase_functions", "supabase_migrations",
    "pgsodium", "pgsodium_masks", "cron", "_analytics", "topology",
} | set(env_list("SCHEMA_EXCLUDE"))

# Web server (python manage.py serve)
HOST = env("HOST", "127.0.0.1")
PORT = int(env("PORT", "5000"))
THREADS = int(env("THREADS", "16"))

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "WARNING"},
}
