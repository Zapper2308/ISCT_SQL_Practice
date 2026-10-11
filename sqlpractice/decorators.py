from functools import wraps

from django.contrib import messages
from django.contrib.auth.views import redirect_to_login
from django.http import Http404
from django.shortcuts import redirect

LOGIN_MESSAGE = "Please log in to start practising."


def login_required(view):
    """Like Django's login_required, plus the "please log in" flash message Flask-Login showed."""
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            messages.info(request, LOGIN_MESSAGE)
            return redirect_to_login(request.get_full_path())
        return view(request, *args, **kwargs)
    return wrapper


def student_only(view):
    """Practice pages are for students; admins are sent to the student-progress view."""
    @wraps(view)
    @login_required
    def wrapper(request, *args, **kwargs):
        if request.user.is_admin:
            return redirect("admin_home")
        return view(request, *args, **kwargs)
    return wrapper


def admin_required(view):
    @wraps(view)
    @login_required
    def wrapper(request, *args, **kwargs):
        if not request.user.is_admin:
            raise Http404
        return view(request, *args, **kwargs)
    return wrapper
