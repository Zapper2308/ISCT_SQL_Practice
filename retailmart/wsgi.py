"""WSGI config - exposes `application` for waitress / gunicorn / mod_wsgi."""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "retailmart.settings")

application = get_wsgi_application()
