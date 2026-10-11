from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("", include("sqlpractice.urls")),
]

handler400 = "sqlpractice.views.bad_request"
handler403 = "sqlpractice.views.permission_denied"
handler404 = "sqlpractice.views.page_not_found"
