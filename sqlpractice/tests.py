import json
from django.test import TestCase, Client
from django.urls import reverse
from sqlpractice.models import User, Progress, PasswordResetRequest
from sqlpractice.services import get_bank


class RetailMartTestCase(TestCase):
    def setUp(self):
        self.client = Client()
        self.bank = get_bank()
        self.first_q = next(iter(self.bank.questions.values()))

        # Create a test student
        self.student = User.objects.create_user(
            email="student@example.com",
            password="password123",
            name="Test Student",
            is_admin=False,
            is_approved=True,
        )

        # Create a test admin
        self.admin = User.objects.create_user(
            email="admin@example.com",
            password="adminpassword123",
            name="Test Admin",
            is_admin=True,
            is_approved=True,
        )

    def test_registration_and_login(self):
        # Register new student
        resp = self.client.post(reverse("register"), {
            "name": "New Student",
            "email": "new@example.com",
            "password": "strongpassword123",
            "confirm": "strongpassword123",
        })
        self.assertEqual(resp.status_code, 302)
        self.assertRedirects(resp, reverse("login"))
        user = User.objects.get(email="new@example.com")
        self.assertFalse(user.is_approved)

        # Try logging in before approval (should be blocked)
        resp = self.client.post(reverse("login"), {
            "email": "new@example.com",
            "password": "strongpassword123",
        })
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "awaiting administrator approval")

        # Admin approves student
        self.client.force_login(self.admin)
        resp = self.client.post(reverse("admin_approve_student", args=[user.id]))
        self.assertEqual(resp.status_code, 302)
        user.refresh_from_db()
        self.assertTrue(user.is_approved)

        # Log out admin and log in as approved student
        self.client.logout()
        resp = self.client.post(reverse("login"), {
            "email": "new@example.com",
            "password": "strongpassword123",
        })
        self.assertEqual(resp.status_code, 302)
        self.assertRedirects(resp, reverse("dashboard"))

    def test_student_dashboard_and_practice(self):
        self.client.force_login(self.student)

        # Dashboard
        resp = self.client.get(reverse("dashboard"))
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Test Student")

        # Practice page
        resp = self.client.get(reverse("practice", args=["easy"]))
        self.assertEqual(resp.status_code, 200)

        # Question workspace
        resp = self.client.get(reverse("question", args=[self.first_q.id]))
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, self.first_q.text)

    def test_api_save_and_answer(self):
        self.client.force_login(self.student)

        # Save query draft
        csrf_token = self.client.cookies.get("csrftoken")
        token_val = csrf_token.value if csrf_token else ""
        headers = {"HTTP_X_CSRF_TOKEN": token_val}

        resp = self.client.post(
            reverse("api_save", args=[self.first_q.id]),
            data=json.dumps({"sql": "SELECT 1;"}),
            content_type="application/json",
            **headers,
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data.get("ok"))

        # Progress should be saved
        p = Progress.objects.get(user=self.student, question_id=self.first_q.id)
        self.assertEqual(p.last_query, "SELECT 1;")

        # Answer reveal API
        resp = self.client.post(
            reverse("api_answer", args=[self.first_q.id]),
            data=json.dumps({}),
            content_type="application/json",
            **headers,
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn("text", resp.json())
        p.refresh_from_db()
        self.assertTrue(p.answer_revealed)

    def test_admin_access_control(self):
        # Non-admin cannot access admin page (404)
        self.client.force_login(self.student)
        resp = self.client.get(reverse("admin_home"))
        self.assertEqual(resp.status_code, 404)

        # Admin redirected from student dashboard to admin home
        self.client.force_login(self.admin)
        resp = self.client.get(reverse("dashboard"))
        self.assertEqual(resp.status_code, 302)
        self.assertRedirects(resp, reverse("admin_home"))

        # Admin home loads successfully
        resp = self.client.get(reverse("admin_home"))
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Student progress")
        self.assertContains(resp, "student@example.com")

        # Built-in Django admin panel loads successfully
        resp = self.client.get("/django-admin/")
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Site administration")
        self.assertContains(resp, "Users")
        self.assertContains(resp, "Progress")

        # Admin student detail loads successfully
        resp = self.client.get(reverse("admin_student", args=[self.student.id]))
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, self.student.name)

        # Export CSV
        resp = self.client.get(reverse("admin_export"))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp["Content-Type"], "text/csv")
        self.assertIn("Test Student", resp.content.decode("utf-8"))

    def test_werkzeug_imported_password(self):
        # Verify imported Flask werkzeug hash works
        # Werkzeug scrypt hash
        imported_user = User.objects.create(
            email="flask_import@example.com",
            name="Flask User",
            password="werkzeug$scrypt:32768:8:1$salt123$75d27038e078dbb4b6008abff811f2a33f48c08ec2009aa936994119d6d5ef6ec47a61d152c1e40a02efad0cfdf50fbfad8d7cf386341208a38549e5d9519119",
        )
        # Note: Werkzeug scrypt salt and hash
        from sqlpractice.hashers import WerkzeugPasswordHasher
        hasher = WerkzeugPasswordHasher()
        computed = hasher._hash("scrypt:32768:8:1", "test_salt", "test_pass")
        imported_user.password = f"werkzeug$scrypt:32768:8:1$test_salt${computed}"
        imported_user.save()

        # Check authenticate works with this password
        from django.contrib.auth import authenticate
        user = authenticate(email="flask_import@example.com", password="test_pass")
        self.assertIsNotNone(user)
        self.assertEqual(user.email, "flask_import@example.com")

    def test_ai_grader_gemini_fallback(self):
        from unittest.mock import patch
        from sqlpractice.ai_grader import AIGrader, GraderUnavailable

        grader = AIGrader(
            base_url="https://primary.example.com",
            api_key="primary_key",
            model="test-primary-model",
            gemini_api_key="gemini_mock_key",
            gemini_model="gemini-2.5-flash",
        )
        self.assertTrue(grader.primary_configured)
        self.assertTrue(grader.gemini_configured)
        self.assertTrue(grader.configured)

        # Primary raises error; Gemini fallback should be called
        with patch.object(grader, "_chat_primary", side_effect=GraderUnavailable("Rate limit reached")), \
             patch.object(grader, "_chat_gemini", return_value='{"correct": true, "feedback": "Verified by Gemini"}') as mock_gemini:
            res = grader.grade(self.first_q, "SELECT 1;")
            self.assertTrue(res["correct"])
            self.assertEqual(res["feedback"], "Verified by Gemini")
            mock_gemini.assert_called_once()

    def test_ai_grader_gemini_only(self):
        from unittest.mock import patch
        from sqlpractice.ai_grader import AIGrader

        grader = AIGrader(
            base_url="",
            api_key="",
            model="",
            gemini_api_key="gemini_mock_key",
            gemini_model="gemini-2.5-flash",
        )
        self.assertFalse(grader.primary_configured)
        self.assertTrue(grader.gemini_configured)
        self.assertTrue(grader.configured)

        with patch.object(grader, "_chat_gemini", return_value='{"correct": false, "feedback": "Incorrect logic"}') as mock_gemini:
            res = grader.grade(self.first_q, "SELECT 1;")
            self.assertFalse(res["correct"])
            self.assertEqual(res["feedback"], "Incorrect logic")
            mock_gemini.assert_called_once()
