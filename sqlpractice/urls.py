from django.urls import path

from . import views

urlpatterns = [
    # auth
    path("register", views.register, name="register"),
    path("login", views.login_view, name="login"),
    path("logout", views.logout_view, name="logout"),
    path("forgot-password", views.forgot_password, name="forgot_password"),
    path("reset-password/<str:uidb64>/<str:token>", views.reset_password, name="reset_password"),

    # student pages
    path("", views.dashboard, name="dashboard"),
    path("practice/<str:difficulty>", views.practice, name="practice"),
    path("question/<str:qid>", views.question, name="question"),

    # admin (teacher) pages
    path("admin", views.admin_home, name="admin_home"),
    path("admin/", views.admin_home),
    path("admin/student/<int:user_id>", views.admin_student, name="admin_student"),
    path("admin/student/<int:user_id>/password", views.admin_reset_password, name="admin_reset_password"),
    path("admin/reset-requests/<int:request_id>/link", views.admin_reset_link, name="admin_reset_link"),
    path("admin/reset-requests/<int:request_id>/dismiss", views.admin_dismiss_reset, name="admin_dismiss_reset"),
    path("admin/students/<int:user_id>/approve", views.admin_approve_student, name="admin_approve_student"),
    path("admin/students/<int:user_id>/reject", views.admin_reject_student, name="admin_reject_student"),
    path("admin/export.csv", views.admin_export, name="admin_export"),

    # JSON API used by static/js/question.js
    path("api/run/<str:qid>", views.api_run, name="api_run"),
    path("api/submit/<str:qid>", views.api_submit, name="api_submit"),
    path("api/save/<str:qid>", views.api_save, name="api_save"),
    path("api/answer/<str:qid>", views.api_answer, name="api_answer"),
    path("api/schema", views.api_schema, name="api_schema"),
]
