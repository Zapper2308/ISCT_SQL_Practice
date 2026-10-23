import os
from datetime import timezone as dt_timezone

from django import template
from django.contrib.staticfiles import finders
from django.templatetags.static import static
from django.utils import timezone

register = template.Library()


@register.simple_tag
def asset(path):
    """Static URL with ?v=<mtime> so browsers pick up CSS/JS edits immediately."""
    url = static(path)
    found = finders.find(path)
    if found and os.path.isfile(found):
        url += f"?v={int(os.path.getmtime(found))}"
    return url


@register.filter
def localdt(dt, fmt="%d %b %Y, %H:%M"):
    """Show a (UTC) timestamp in Indian Standard Time (settings.TIME_ZONE = Asia/Kolkata)."""
    if not dt:
        return ""
    if timezone.is_naive(dt):
        dt = timezone.make_aware(dt, dt_timezone.utc)
    return timezone.localtime(dt).strftime(fmt)


@register.filter
def first_word(value):
    return (value or "").split(" ")[0]


@register.filter
def initial(value):
    return (value or "")[:1].upper()
