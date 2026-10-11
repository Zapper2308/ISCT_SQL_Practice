from .services import get_sandbox
from .stats import DIFFICULTY_CHOICES


def globals(request):
    return {"DIFFICULTY_CHOICES": DIFFICULTY_CHOICES, "db_configured": get_sandbox().configured}
