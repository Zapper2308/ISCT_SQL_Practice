"""Process-wide singletons (question bank, query sandbox, AI grader).

Created lazily so management commands like `migrate` don't parse the whole question bank.
"""
from functools import cache

from django.conf import settings

from .ai_grader import AIGrader
from .question_bank import QuestionBank
from .sandbox import Sandbox


@cache
def get_bank() -> QuestionBank:
    return QuestionBank(str(settings.PRACTICE_DIR))


@cache
def get_sandbox() -> Sandbox:
    return Sandbox(
        settings.PRACTICE_DATABASE_URL,
        timeout_s=settings.QUERY_TIMEOUT_SECONDS,
        max_display_rows=500,
        grade_row_limit=5000,
        pool_max=settings.DB_POOL_MAX,
    )


@cache
def get_ai_grader() -> AIGrader:
    return AIGrader(
        settings.LLM_BASE_URL,
        settings.LLM_API_KEY,
        settings.LLM_MODEL,
        gemini_api_key=settings.GEMINI_API_KEY,
        gemini_model=settings.GEMINI_MODEL,
    )
