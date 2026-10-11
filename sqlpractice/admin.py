from django.contrib import admin
from .models import User, Progress, PasswordResetRequest


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("email", "name", "is_approved", "is_admin", "is_active", "created_at")
    list_filter = ("is_approved", "is_admin", "is_active")
    search_fields = ("email", "name")
    ordering = ("-created_at",)


@admin.register(Progress)
class ProgressAdmin(admin.ModelAdmin):
    list_display = ("user", "question_id", "difficulty", "topic_slug", "status", "solved_method", "attempts", "answer_revealed", "updated_at")
    list_filter = ("difficulty", "status", "solved_method", "answer_revealed")
    search_fields = ("question_id", "user__email", "user__name", "topic_slug")
    ordering = ("-updated_at",)


@admin.register(PasswordResetRequest)
class PasswordResetRequestAdmin(admin.ModelAdmin):
    list_display = ("user", "created_at", "emailed", "resolved_at")
    list_filter = ("emailed", "resolved_at")
    search_fields = ("user__email", "user__name")
    ordering = ("-created_at",)
