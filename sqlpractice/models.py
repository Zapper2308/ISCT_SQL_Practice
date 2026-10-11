from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, name="", is_approved=False, **extra):
        if not email:
            raise ValueError("An email address is required.")
        user = self.model(email=self.normalize_email(email).lower(), name=name or email, is_approved=is_approved, **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, name="", **extra):
        extra["is_admin"] = True
        extra["is_approved"] = True
        return self.create_user(email, password, name, is_approved=True, **extra)


class User(AbstractBaseUser):
    """A student (or, with is_admin, a teacher who monitors students). Logs in with email."""
    # Longer than Django's default 128 chars so imported Flask (werkzeug scrypt) hashes fit.
    password = models.CharField("password", max_length=255)
    name = models.CharField(max_length=120)
    email = models.EmailField(max_length=255, unique=True)
    is_admin = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    def __str__(self):
        return f"{self.name} <{self.email}>"

    @property
    def is_staff(self):
        return self.is_admin

    @property
    def is_superuser(self):
        return self.is_admin

    def has_perm(self, perm, obj=None):
        return self.is_admin

    def has_perms(self, perm_list, obj=None):
        return self.is_admin

    def has_module_perms(self, app_label):
        return self.is_admin


class Progress(models.Model):
    """One row per (student, question) the student has touched."""
    STATUS_ATTEMPTED = "attempted"
    STATUS_SOLVED = "solved"

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="progress")
    question_id = models.CharField(max_length=32)            # e.g. "05-medium-26"
    difficulty = models.CharField(max_length=10)
    topic_slug = models.CharField(max_length=80)
    status = models.CharField(max_length=12, default=STATUS_ATTEMPTED)   # attempted | solved
    solved_method = models.CharField(max_length=8, null=True, blank=True)  # auto | ai | self (legacy)
    attempts = models.PositiveIntegerField(default=0)
    answer_revealed = models.BooleanField(default=False)
    submissions = models.PositiveIntegerField(default=0)
    last_query = models.TextField(blank=True, default="")
    solved_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "progress"
        constraints = [
            models.UniqueConstraint(fields=["user", "question_id"], name="progress_user_question_uniq"),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.question_id} ({self.status})"


class PasswordResetRequest(models.Model):
    """A student's "forgot password" request, shown to admins until it is resolved."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="reset_requests")
    created_at = models.DateTimeField(default=timezone.now)
    emailed = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Reset request for {self.user_id} at {self.created_at:%Y-%m-%d %H:%M}"
