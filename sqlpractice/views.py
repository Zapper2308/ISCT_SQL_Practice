"""RetailMart SQL Practice - Django views.

Students register, pick a difficulty -> topic tab -> section, open a question,
write PostgreSQL in the top pane and see results in the bottom pane.
"""
import csv
import json
import logging
import re
from collections import defaultdict
from datetime import timedelta

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import authenticate
from django.contrib.auth import login as auth_login
from django.contrib.auth import logout as auth_logout
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import PermissionDenied
from django.core.mail import send_mail
from django.db.models import Count, Sum
from django.http import Http404, HttpResponse, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.utils.encoding import force_bytes
from django.utils.http import url_has_allowed_host_and_scheme, urlsafe_base64_decode, urlsafe_base64_encode
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from .ai_grader import GraderUnavailable
from .decorators import admin_required, login_required, student_only
from .models import PasswordResetRequest, Progress, User
from .question_bank import DIFFICULTIES
from .sandbox import display_value, split_statements
from .services import get_ai_grader, get_bank, get_sandbox
from .stats import DIFFICULTY_LABELS, SOLVED_METHOD_LABELS, pct, student_overview, summarize

logger = logging.getLogger(__name__)

MAX_SQL_LENGTH = 50000


# ----------------------------------------------------------------- helpers

def user_progress(user):
    """{question_id: Progress} for one student."""
    return {p.question_id: p for p in Progress.objects.filter(user=user)}


def get_progress(user, question, create=False):
    if create:
        p, _ = Progress.objects.get_or_create(
            user=user, question_id=question.id,
            defaults={"difficulty": question.difficulty, "topic_slug": question.topic_slug},
        )
        return p
    return Progress.objects.filter(user=user, question_id=question.id).first()


def safe_next(request, target):
    if target and target.startswith("/") and url_has_allowed_host_and_scheme(
            target, allowed_hosts={request.get_host()}, require_https=request.is_secure()):
        return target
    return reverse("dashboard")


def question_or_404(qid):
    q = get_bank().questions.get(qid)
    if q is None:
        raise Http404
    return q


def json_body(request):
    try:
        data = json.loads(request.body or b"{}")
    except (ValueError, UnicodeDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def submitted_sql(request):
    value = json_body(request).get("sql", "")
    return value if isinstance(value, str) else ""


def resolve_reset_requests(user):
    PasswordResetRequest.objects.filter(user=user, resolved_at__isnull=True).update(resolved_at=timezone.now())


# ----------------------------------------------------------------- auth

@require_http_methods(["GET", "POST"])
def register(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    form = {"name": "", "email": ""}
    if request.method == "POST":
        form["name"] = request.POST.get("name", "").strip()
        form["email"] = request.POST.get("email", "").strip().lower()
        password = request.POST.get("password", "")
        confirm = request.POST.get("confirm", "")
        error = None
        if not form["name"] or not form["email"]:
            error = "Name and email are required."
        elif "@" not in form["email"]:
            error = "Please enter a valid email address."
        elif len(password) < 8:
            error = "Password must be at least 8 characters."
        elif password != confirm:
            error = "Passwords don't match."
        elif User.objects.filter(email=form["email"]).exists():
            error = "An account with this email already exists - log in instead."
        if error:
            messages.error(request, error)
        else:
            user = User.objects.create_user(form["email"], password, name=form["name"], is_approved=False)
            messages.success(
                request,
                f"Registration received for {user.name}! Your account is pending administrator approval before you can log in."
            )
            return redirect("login")
    return render(request, "register.html", {"form": form})


@require_http_methods(["GET", "POST"])
def login_view(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    email = ""
    if request.method == "POST":
        email = request.POST.get("email", "").strip().lower()
        user = authenticate(request, email=email, password=request.POST.get("password", ""))
        if user is not None:
            if not user.is_approved and not user.is_admin:
                messages.warning(
                    request,
                    "Your account has been registered but is awaiting administrator approval. Please contact your instructor."
                )
                return render(request, "login.html", {"email": email})
            auth_login(request, user)
            if not request.POST.get("remember"):
                request.session.set_expiry(0)      # expire when the browser closes
            if user.is_admin:
                return redirect("admin_home")
            return redirect(safe_next(request, request.GET.get("next")))
        messages.error(request, "Incorrect email or password.")
    return render(request, "login.html", {"email": email})


@require_POST
@login_required
def logout_view(request):
    auth_logout(request)
    return redirect("login")


# ----------------------------------------------------------------- password reset

def make_reset_link(request, user):
    """One-time link: Django's token stops working once the password changes or after RESET_LINK_HOURS."""
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    path = reverse("reset_password", args=[uid, default_token_generator.make_token(user)])
    base = settings.APP_BASE_URL or request.build_absolute_uri("/").rstrip("/")
    return f"{base}{path}"


def user_from_reset_token(uidb64, token):
    try:
        user = User.objects.get(pk=urlsafe_base64_decode(uidb64).decode())
    except (TypeError, ValueError, OverflowError, User.DoesNotExist):
        return None
    return user if default_token_generator.check_token(user, token) else None


def send_reset_email(request, user):
    hours = settings.RESET_LINK_HOURS
    send_mail(
        "Reset your RetailMart SQL Practice password",
        f"Hi {user.name},\n\n"
        f"Someone asked to reset the password for your RetailMart SQL Practice account.\n"
        f"Open this link to choose a new password (it works once and expires in {hours} hours):\n\n"
        f"{make_reset_link(request, user)}\n\n"
        f"If you didn't ask for this, you can ignore this email - your password stays the same.\n",
        settings.DEFAULT_FROM_EMAIL,
        [user.email],
    )


@require_http_methods(["GET", "POST"])
def forgot_password(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    sent = False
    if request.method == "POST":
        email = request.POST.get("email", "").strip().lower()
        user = User.objects.filter(email=email).first()
        if user:
            pending = user.reset_requests.filter(resolved_at__isnull=True).order_by("-created_at").first()
            recent = pending and pending.created_at > timezone.now() - timedelta(minutes=5)
            if not recent:
                req = pending or PasswordResetRequest(user=user)
                req.created_at = timezone.now()
                if settings.EMAIL_ENABLED:
                    try:
                        send_reset_email(request, user)
                        req.emailed = True
                    except Exception as e:  # SMTP problems: fall back to the admin queue
                        logger.warning("Password reset email failed: %s", e)
                req.save()
        sent = True    # same response whether or not the account exists
    return render(request, "forgot_password.html", {"sent": sent, "email_enabled": settings.EMAIL_ENABLED})


@require_http_methods(["GET", "POST"])
def reset_password(request, uidb64, token):
    user = user_from_reset_token(uidb64, token)
    if user is None:
        return render(request, "reset_password.html", {"invalid": True})
    if request.method == "POST":
        password = request.POST.get("password", "")
        if len(password) < 8:
            messages.error(request, "Password must be at least 8 characters.")
        elif password != request.POST.get("confirm", ""):
            messages.error(request, "Passwords don't match.")
        else:
            user.set_password(password)
            user.save(update_fields=["password"])
            resolve_reset_requests(user)
            auth_logout(request)
            messages.success(request, "Your password has been changed - log in with the new one.")
            return redirect("login")
    return render(request, "reset_password.html", {"invalid": False, "reset_user": user})


# ----------------------------------------------------------------- pages

@require_GET
@student_only
def dashboard(request):
    return render(request, "dashboard.html", summarize(user_progress(request.user)))


@require_GET
@student_only
def practice(request, difficulty):
    if difficulty not in DIFFICULTIES:
        raise Http404
    bank = get_bank()
    progress = user_progress(request.user)
    topic = bank.topic_by_slug.get(request.GET.get("topic")) or bank.topics[0]
    sections = topic.sections.get(difficulty, [])
    section = next((s for s in sections if s.letter == request.GET.get("section")),
                   sections[0] if sections else None)

    def status_of(q):
        p = progress.get(q.id)
        return p.status if p else "new"

    def tab(questions, **extra):
        solved = sum(1 for q in questions if status_of(q) == Progress.STATUS_SOLVED)
        total = len(questions)
        return {**extra, "solved": solved, "total": total, "pct": pct(solved, total),
                "done": bool(total) and solved == total}

    return render(request, "practice.html", {
        "difficulty": difficulty,
        "difficulty_label": DIFFICULTY_LABELS[difficulty],
        "nav_difficulty": difficulty,
        "topic": topic,
        "section": section,
        "topic_tabs": [tab(t.questions(difficulty), topic=t) for t in bank.topics],
        "section_tabs": [tab(s.questions, section=s) for s in sections],
        "questions": [{"q": q, "status": status_of(q)} for q in section.questions] if section else [],
    })


@require_GET
@student_only
def question(request, qid):
    bank = get_bank()
    q = question_or_404(qid)
    prev_q, next_q = bank.neighbours(q)
    p = get_progress(request.user, q)
    topic = bank.topic_by_slug[q.topic_slug]
    section = next(s for s in topic.sections[q.difficulty] if s.letter == q.section)
    can_reveal = settings.ALLOW_ANSWER_REVEAL or request.user.is_admin
    page_data = {
        "qid": q.id,
        "number": q.number,
        "isSql": q.is_sql,
        "initial": p.last_query if p and p.last_query else "",
        "nextUrl": reverse("question", args=[next_q.id]) if next_q else None,
        "urls": {
            "run": reverse("api_run", args=[q.id]),
            "save": reverse("api_save", args=[q.id]),
            "submit": reverse("api_submit", args=[q.id]),
            "answer": reverse("api_answer", args=[q.id]) if can_reveal else None,
            "schema": reverse("api_schema"),
        },
    }
    return render(request, "question.html", {
        "q": q, "topic": topic, "section": section, "progress": p,
        "status": p.status if p else "new",
        "difficulty_label": DIFFICULTY_LABELS[q.difficulty],
        "nav_difficulty": q.difficulty,
        "prev_q": prev_q, "next_q": next_q, "can_reveal": can_reveal, "page_data": page_data,
    })


# ----------------------------------------------------------------- admin

@require_GET
@admin_required
def admin_home(request):
    bank = get_bank()
    students = student_overview()
    week_ago = timezone.now() - timedelta(days=7)
    n = len(students)

    total_solved = sum(s["solved"] for s in students)
    summary = {
        "students": n,
        "active_week": sum(1 for s in students if s["last_active"] and s["last_active"] >= week_ago),
        "solved": total_solved,
        "avg_solved": round(total_solved / n, 1) if n else 0,
        "total_questions": sum(bank.totals.values()),
    }
    approval_requests = list(User.objects.filter(is_admin=False, is_approved=False).order_by("-created_at"))
    reset_requests = (PasswordResetRequest.objects.filter(resolved_at__isnull=True)
                      .select_related("user").order_by("-created_at"))
    return render(request, "admin.html", {
        "students": students, "summary": summary,
        "approval_requests": approval_requests,
        "reset_requests": list(reset_requests), "reset_hours": settings.RESET_LINK_HOURS,
    })


@require_POST
@admin_required
def admin_approve_student(request, user_id):
    student = get_object_or_404(User, pk=user_id, is_admin=False)
    student.is_approved = True
    student.save(update_fields=["is_approved"])
    messages.success(request, f"Approved registration for {student.name} ({student.email}).")
    return redirect("admin_home")


@require_POST
@admin_required
def admin_reject_student(request, user_id):
    student = get_object_or_404(User, pk=user_id, is_admin=False)
    name, email = student.name, student.email
    student.delete()
    messages.info(request, f"Rejected and removed registration request for {name} ({email}).")
    return redirect("admin_home")


@require_GET
@admin_required
def admin_student(request, user_id):
    bank = get_bank()
    student = get_object_or_404(User, pk=user_id)
    rows = list(Progress.objects.filter(user=student).order_by("-updated_at"))
    attempts = []
    for p in rows:
        q = bank.questions.get(p.question_id)
        if q is None:
            continue
        topic = bank.topic_by_slug[q.topic_slug]
        attempts.append({
            "p": p, "q": q, "topic": topic, "label": DIFFICULTY_LABELS[q.difficulty],
            "method_label": SOLVED_METHOD_LABELS.get(p.solved_method, "self-marked"),
            "search": f"{topic.title} {q.text}".lower(),
        })
    return render(request, "admin_student.html", {
        "student": student, "attempts": attempts, **summarize({p.question_id: p for p in rows}),
    })


@require_POST
@admin_required
def admin_reset_password(request, user_id):
    student = get_object_or_404(User, pk=user_id)
    password = request.POST.get("password", "")
    if len(password) < 8:
        messages.error(request, "The new password must be at least 8 characters.")
    else:
        student.set_password(password)
        student.save(update_fields=["password"])
        resolve_reset_requests(student)
        messages.success(request, f"Password updated for {student.name}. Share it with them privately.")
    return redirect("admin_student", user_id=student.id)


@require_POST
@admin_required
def admin_reset_link(request, request_id):
    """Creates a one-time reset link for the admin to send to the student."""
    req = get_object_or_404(PasswordResetRequest.objects.select_related("user"), pk=request_id)
    return JsonResponse({"ok": True, "link": make_reset_link(request, req.user), "hours": settings.RESET_LINK_HOURS})


@require_POST
@admin_required
def admin_dismiss_reset(request, request_id):
    req = get_object_or_404(PasswordResetRequest, pk=request_id)
    req.resolved_at = timezone.now()
    req.save(update_fields=["resolved_at"])
    return redirect("admin_home")


@require_GET
@admin_required
def admin_export(request):
    filename = f"student_results_{timezone.now():%Y%m%d}.csv"
    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = f"attachment; filename={filename}"
    writer = csv.writer(response)
    writer.writerow(["name", "email", "registered", "last_active", "solved", "result_match", "ai_checked", "self_marked",
                     *[f"{d}_solved" for d in DIFFICULTIES], "in_progress", "queries_run", "answers_revealed"])
    for s in student_overview():
        u = s["user"]
        writer.writerow([u.name, u.email, u.created_at.strftime("%Y-%m-%d"),
                         s["last_active"].strftime("%Y-%m-%d %H:%M") if s["last_active"] else "",
                         s["solved"], s["auto"], s["ai"], s["self_marked"],
                         *[s["by_diff"][d] for d in DIFFICULTIES], s["attempted"], s["runs"], s["revealed"]])
    return response


# ----------------------------------------------------------------- JSON API

def run_for_grading(sql):
    """Runs SQL fetching enough rows to grade; returns (result, display payload)."""
    sandbox = get_sandbox()
    result = sandbox.run(sql, row_limit=sandbox.grade_row_limit)
    rows, truncated = result["rows"], result["truncated"]
    if sandbox.max_display_rows and sandbox.max_display_rows > 0 and len(rows) > sandbox.max_display_rows:
        rows, truncated = rows[:sandbox.max_display_rows], True
    payload = {
        "ok": result["ok"],
        "columns": result["columns"],
        "rows": [[display_value(v) for v in r] for r in rows],
        "truncated": truncated,
        "row_limit": sandbox.max_display_rows or len(rows),
        "messages": result["messages"],
        "error": result["error"],
        "elapsed_ms": result["elapsed_ms"],
    }
    return result, payload


def written_answer(text):
    """Editor contents minus the starter comment line and blank lines."""
    lines = [ln for ln in text.splitlines() if not re.match(r"\s*--\s*Q\d+:", ln)]
    return "\n".join(lines).strip()


def accept(p, method):
    if p.status != Progress.STATUS_SOLVED:
        p.status, p.solved_method, p.solved_at = Progress.STATUS_SOLVED, method, timezone.now()


@require_POST
@login_required
def api_run(request, qid):
    """Runs the student's SQL. Running never marks a question solved - Submit does."""
    q = question_or_404(qid)
    sql = submitted_sql(request)
    if len(sql) > MAX_SQL_LENGTH:
        return JsonResponse({"ok": False, "error": {"message": "Query is too long (max 50,000 characters)."}},
                            status=400)

    result, payload = run_for_grading(sql)
    grade = get_sandbox().grade(q, result) if result["ok"] else None

    p = get_progress(request.user, q, create=True)
    p.attempts += 1
    p.last_query = sql
    p.save()
    return JsonResponse({**payload, "grade": grade, "status": p.status})


@require_POST
@login_required
def api_submit(request, qid):
    """Accepts the answer only if it is correct: exact result match first, then the AI checker."""
    q = question_or_404(qid)
    text = submitted_sql(request)[:MAX_SQL_LENGTH]
    p = get_progress(request.user, q, create=True)
    p.last_query = text
    p.submissions += 1
    response = {"accepted": False, "result": None}

    answer = written_answer(text)
    is_empty = not split_statements(answer) if q.is_sql else len(answer.split()) < 3
    if is_empty:
        p.save()
        return JsonResponse({**response, "verdict": "empty",
                             "feedback": "Write your answer in the editor before submitting."})

    if q.is_sql:
        result, payload = run_for_grading(text)
        response["result"] = payload
        if not result["ok"]:
            p.save()
            return JsonResponse({**response, "verdict": "error",
                                 "feedback": "Your query has an error - fix it and submit again."})
        grade = get_sandbox().grade(q, result)
        if grade["verdict"] == "correct":
            accept(p, "auto")
            p.save()
            return JsonResponse({**response, "accepted": True, "verdict": "correct", "method": "auto",
                                 "feedback": grade["reason"], "status": p.status})

    # The AI compares the submitted query / written answer with the answer key (text only, no results).
    try:
        judgement = get_ai_grader().grade(q, answer)
    except GraderUnavailable as e:
        p.save()
        return JsonResponse({**response, "verdict": "unavailable", "feedback": str(e), "status": p.status})

    if judgement["correct"]:
        accept(p, "ai")
    p.save()
    return JsonResponse({**response, "accepted": judgement["correct"],
                         "verdict": "correct" if judgement["correct"] else "incorrect", "method": "ai",
                         "feedback": judgement["feedback"] or ("Correct!" if judgement["correct"] else "Not quite - try again."),
                         "status": p.status})


@require_POST
@login_required
def api_save(request, qid):
    """Saves the editor contents (drafts / written answers to conceptual questions)."""
    q = question_or_404(qid)
    p = get_progress(request.user, q, create=True)
    p.last_query = submitted_sql(request)[:MAX_SQL_LENGTH]
    p.save()
    return JsonResponse({"ok": True})


@require_POST
@login_required
def api_answer(request, qid):
    """Reveals the answer key (after the page's arithmetic check) and records that it was revealed."""
    if not (settings.ALLOW_ANSWER_REVEAL or request.user.is_admin):
        raise PermissionDenied
    q = question_or_404(qid)
    if not request.user.is_admin:
        p = get_progress(request.user, q, create=True)
        p.answer_revealed = True
        p.save()
    return JsonResponse({"text": q.answer_text, "sql": q.answer_sql})


@require_GET
@login_required
def api_schema(request):
    refresh = request.GET.get("refresh") in ("1", "true")
    return JsonResponse(get_sandbox().schema(settings.SCHEMA_EXCLUDE, refresh=refresh), safe=False)


# ----------------------------------------------------------------- errors

def _error(request, code, message):
    if request.path.startswith("/api/"):
        return JsonResponse({"ok": False, "error": {"message": message}}, status=code)
    return render(request, "error.html", {"code": code, "message": message}, status=code)


def page_not_found(request, exception=None):
    return render(request, "error.html", {"code": 404, "message": "That page doesn't exist."}, status=404)


def bad_request(request, exception=None):
    return _error(request, 400, "Bad request - reload the page and try again.")


def permission_denied(request, exception=None):
    return _error(request, 403, "You don't have access to that.")


def csrf_failure(request, reason=""):
    return _error(request, 400, "Invalid or missing CSRF token - reload the page and try again.")
