"""Progress summaries for the student dashboard and the admin pages.

Results are shaped as lists of dicts so Django templates can render them without dict-key lookups.
"""
from collections import defaultdict
from datetime import timedelta

from django.db.models import Count, Max, Q, Sum
from django.utils import timezone

from .models import Progress, User
from .question_bank import DIFFICULTIES
from .services import get_bank

DIFFICULTY_LABELS = {"easy": "Easy", "medium": "Medium", "hard": "Hard", "crazy": "Crazy"}
DIFFICULTY_CHOICES = [(d, DIFFICULTY_LABELS[d]) for d in DIFFICULTIES]
SOLVED_METHOD_LABELS = {"auto": "result match", "ai": "AI-checked"}
STUDENT_STATUS = {"active": (1, "Active"), "inactive": (2, "Inactive"), "not-started": (3, "Not started")}


def pct(a, b):
    return round(a / b * 100, 1) if b else 0


def cell_state(solved, total):
    return "done" if total and solved == total else ("some" if solved else "")


def summarize(progress):
    """Dashboard numbers for one student's {question_id: Progress}."""
    bank = get_bank()
    solved = [p for p in progress.values() if p.status == Progress.STATUS_SOLVED]

    by_diff = {d: {"solved": 0, "attempted": 0, "total": bank.totals[d]} for d in DIFFICULTIES}
    by_topic = defaultdict(lambda: {d: 0 for d in DIFFICULTIES})
    for p in progress.values():
        if p.difficulty not in by_diff:
            continue
        if p.status == Progress.STATUS_SOLVED:
            by_diff[p.difficulty]["solved"] += 1
            by_topic[p.topic_slug][p.difficulty] += 1
        else:
            by_diff[p.difficulty]["attempted"] += 1

    diff_cards = [{"key": d, "label": DIFFICULTY_LABELS[d], **s, "pct": pct(s["solved"], s["total"])}
                  for d, s in by_diff.items()]

    topic_rows = []
    for t in bank.topics:
        cells = []
        for d in DIFFICULTIES:
            n_solved, n_total = by_topic[t.slug][d], len(t.questions(d))
            cells.append({"key": d, "solved": n_solved, "total": n_total,
                          "pct": pct(n_solved, n_total), "state": cell_state(n_solved, n_total)})
        topic_rows.append({"topic": t, "cells": cells, "solved": sum(c["solved"] for c in cells),
                           "total": sum(c["total"] for c in cells)})

    week_ago = timezone.now() - timedelta(days=7)
    recent = sorted(progress.values(), key=lambda p: p.updated_at, reverse=True)[:10]
    total = sum(bank.totals.values())
    auto = sum(1 for p in solved if p.solved_method == "auto")
    ai = sum(1 for p in solved if p.solved_method == "ai")
    stats = {
        "solved": len(solved),
        "total": total,
        "pct": pct(len(solved), total),
        "attempted": len(progress) - len(solved),
        "auto": auto,
        "ai": ai,
        "self_marked": len(solved) - auto - ai,
        "week": sum(1 for p in solved if p.solved_at and p.solved_at >= week_ago),
        "runs": sum(p.attempts for p in progress.values()),
        "revealed": sum(1 for p in progress.values() if p.answer_revealed),
        "last_active": recent[0].updated_at if recent else None,
    }
    recent_rows = []
    for p in recent:
        q = bank.questions.get(p.question_id)
        if q:
            recent_rows.append({"p": p, "q": q, "topic": bank.topic_by_slug[q.topic_slug],
                                "label": DIFFICULTY_LABELS[q.difficulty]})
    return {"stats": stats, "diff_cards": diff_cards, "topic_rows": topic_rows, "recent": recent_rows}


def student_overview():
    """One summary row per student (non-admin, approved users), most solved first."""
    bank = get_bank()
    students = User.objects.filter(is_admin=False, is_approved=True)
    rows = {u.id: {"user": u, "solved": 0, "auto": 0, "ai": 0, "attempted": 0, "runs": 0, "revealed": 0,
                   "last_active": None, "by_diff": {d: 0 for d in DIFFICULTIES}} for u in students}
    agg = (Progress.objects
           .values("user_id", "difficulty", "status", "solved_method")
           .annotate(count=Count("id"), runs=Sum("attempts"),
                     revealed=Count("id", filter=Q(answer_revealed=True)), last=Max("updated_at"))
           .order_by())
    for a in agg:
        r = rows.get(a["user_id"])
        if r is None:
            continue
        count, method = a["count"], a["solved_method"]
        r["runs"] += a["runs"] or 0
        r["revealed"] += a["revealed"] or 0
        if a["last"] and (r["last_active"] is None or a["last"] > r["last_active"]):
            r["last_active"] = a["last"]
        if a["status"] == Progress.STATUS_SOLVED:
            r["solved"] += count
            r["auto"] += count if method == "auto" else 0
            r["ai"] += count if method == "ai" else 0
            if a["difficulty"] in r["by_diff"]:
                r["by_diff"][a["difficulty"]] += count
        else:
            r["attempted"] += count

    week_ago = timezone.now() - timedelta(days=7)
    total = sum(bank.totals.values())
    for r in rows.values():
        if r["last_active"] is None:
            r["status"] = "not-started"
        elif r["last_active"] >= week_ago:
            r["status"] = "active"
        else:
            r["status"] = "inactive"
        r["status_order"], r["status_label"] = STUDENT_STATUS[r["status"]]
        r["self_marked"] = r["solved"] - r["auto"] - r["ai"]
        r["pct"] = pct(r["solved"], total)
        r["diff_cells"] = [{"key": d, "solved": r["by_diff"][d], "total": bank.totals[d]} for d in DIFFICULTIES]
    return sorted(rows.values(), key=lambda r: (-r["solved"], r["user"].name.lower()))
