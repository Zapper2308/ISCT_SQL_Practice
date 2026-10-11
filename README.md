# SQL Query Practice

A full-featured web platform where students learn and practise PostgreSQL queries against the RetailMart retail dataset, with automated result matching and AI-powered evaluation.

---

## Features

- **Dashboard**: High-level KPIs, progress breakdowns by difficulty (Easy, Medium, Hard, Crazy), and a comprehensive 28-topic progress matrix.
- **Practice Workspace**: 28 structured SQL topics, each split into 4 sections (A–D). Students can filter by All, Unsolved, or Solved.
- **Interactive Query Editor**:
  - CodeMirror SQL editor with PostgreSQL syntax highlighting, bracket matching, and schema autocompletion (Ctrl+Space).
  - Split-pane layout with draggable divider.
  - White high-visibility cursor and clear error indicators.
  - Interactive table schema browser showing table names, columns, and data types.
- **Dual Evaluation System (Run vs Submit)**:
  - **Run (`Ctrl+Enter`)**: Executes the query in a sandboxed, rolled-back transaction to safely view results without affecting progress.
  - **Submit**: Evaluates the solution:
    1. Rejects queries with SQL syntax or execution errors.
    2. **Deterministic Match**: If query results match the answer key (ignoring order/formatting differences), it accepts immediately.
    3. **AI Evaluation (Optional)**: If results differ slightly or for conceptual questions, an LLM evaluates query equivalence without revealing the answer key.
- **AI Answer Evaluation**:
  - Primary provider: Ollama Cloud or OpenAI-compatible endpoint.
  - Automatic fallback: Google Gemini API (`gemini-3.5-flash-lite`).
- **Student Approval Workflow**: Newly registered students require instructor approval from the Admin dashboard before accessing practice materials.
- **Admin Dashboard**:
  - Student approval queue (Approve / Reject).
  - Student activity report with search, sorting, and CSV export.
  - Detailed student inspection (solved questions, in-progress attempts, revealed answers).
  - Password reset link generation.

---

## Tech Stack

- **Backend**: Python 3.10+, Django 5/6
- **Database**: PostgreSQL (Supabase with connection pooler) or local PostgreSQL / SQLite
- **Static Files**: WhiteNoise
- **WSGI Servers**: Waitress (Windows / local), Gunicorn (Linux / production)
- **Frontend**: Vanilla JS, CodeMirror 5, CSS custom properties

---

## Quick Start (Local Windows)

1. Clone or extract the project:
   ```cmd
   git clone <repo-url>
   cd isct_retailmart
   ```
2. Copy `.env.example` to `.env`:
   ```cmd
   copy .env.example .env
   ```
3. Edit `.env` to configure your database connection strings:
   - `APP_DATABASE_URL`: Connection string for user accounts and progress (e.g. Supabase or local SQLite).
   - `PRACTICE_DATABASE_URL`: Connection string for the RetailMart dataset.
4. Double-click **`run.bat`** (or run `run.bat` in Command Prompt). The script automatically:
   - Creates the Python virtual environment (`.venv`).
   - Installs all dependencies from `requirements.txt`.
   - Runs database migrations.
   - Launches the local production server at `http://localhost:5000`.
5. Run **`create_admin.bat`** in a separate terminal to create your instructor/admin account:
   ```cmd
   create_admin.bat
   ```

---

## Quick Start (Linux / macOS / Manual)

1. Create and activate a virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```
4. Run migrations:
   ```bash
   python manage.py migrate
   ```
5. Create an admin user:
   ```bash
   python manage.py create_admin --email admin@example.com --name "Instructor"
   ```
6. Start the server:
   ```bash
   # Development server:
   python manage.py runserver

   # Or production WSGI server:
   python manage.py serve --host 127.0.0.1 --port 5000
   ```

---

## Production Deployment

This project is configured for one-click deployment on platforms like **Render**, **Railway**, **Fly.io**, **Heroku**, or any Linux VPS.

### 1. Deployment Settings on Cloud Platforms (Render / Railway)

- **Environment**: Python 3
- **Build Command**:
  ```bash
  pip install -r requirements.txt && python manage.py migrate && python manage.py collectstatic --no-input
  ```
- **Start Command**:
  ```bash
  gunicorn retailmart.wsgi:application
  ```
  *(Or rely on the included `Procfile`: `web: gunicorn retailmart.wsgi:application`)*

### 2. Required Production Environment Variables

Set these in your host's environment settings:

| Variable | Description | Example |
|---|---|---|
| `DEBUG` | Disable debug mode | `False` |
| `DJANGO_SECRET_KEY` | Strong random secret key | Run: `python -c "import secrets; print(secrets.token_hex(32))"` |
| `ALLOWED_HOSTS` | Domains allowed to access the app | `your-app.onrender.com,localhost` |
| `CSRF_TRUSTED_ORIGINS` | Trusted origins for HTTPS forms | `https://your-app.onrender.com` |
| `APP_DATABASE_URL` | Supabase Postgres URL (Pooler) | `postgresql://postgres.xxx:pass@aws-0-xx.pooler.supabase.com:5432/postgres` |
| `PRACTICE_DATABASE_URL` | RetailMart database URL | `postgresql://sql_student:pass@db-host:5432/isct_retailmart` |
| `LLM_API_KEY` | *(Optional)* Ollama Cloud API key | `your-ollama-api-key` |
| `GEMINI_API_KEY` | *(Optional)* Google Gemini API key | `your-gemini-api-key` |

---

## Database Security & Sandboxing

All student queries run inside a dedicated transaction that is **always rolled back**. This guarantees:
- `INSERT`, `UPDATE`, `DELETE`, and `DROP/CREATE` statements never mutate the shared practice database.
- Queries timeout after `QUERY_TIMEOUT_SECONDS` (default: 15s).
- Query output is capped to `MAX_RESULT_ROWS` (default: 500) to protect browser and server memory.

### Recommended Low-Privilege Practice Role (PostgreSQL)

To restrict student access exclusively to practice tables and protect system schemas, execute the following in your PostgreSQL database:

```sql
CREATE ROLE sql_student LOGIN PASSWORD 'your-strong-password';

DO $$
DECLARE s text;
BEGIN
  FOR s IN SELECT nspname FROM pg_namespace
           WHERE nspname NOT LIKE 'pg\_%' AND nspname NOT IN
             ('information_schema','auth','storage','realtime','_realtime','extensions','graphql',
              'graphql_public','pgbouncer','vault','net','supabase_functions','supabase_migrations',
              'pgsodium','pgsodium_masks','cron','_analytics','public')
  LOOP
    EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO sql_student', s);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA %I TO sql_student', s);
    EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO sql_student', s);
  END LOOP;
END $$;

GRANT pg_read_all_stats TO sql_student;
```

---

## Project Structure

```
├── .env.example             # Template for environment configuration
├── .gitignore               # Excludes secrets, caches, and virtualenvs
├── manage.py                # Django CLI tool
├── Procfile                 # Process file for cloud deployment
├── requirements.txt         # Production dependencies
├── run.bat                  # One-click Windows runner
├── create_admin.bat         # One-click admin creation utility
├── Practice/                # 28 SQL practice topics & answer keys
├── retailmart/              # Django core settings, urls, wsgi
├── sqlpractice/             # Main application
│   ├── ai_grader.py         # LLM query comparison & grading
│   ├── models.py            # User, Progress, PasswordResetRequest
│   ├── question_bank.py     # Parses question files
│   ├── sandbox.py           # Sandboxed query runner
│   ├── views.py             # Auth, dashboard, practice, admin endpoints
│   └── management/commands/ # Custom Django CLI commands
├── static/                  # CSS, JavaScript, and branding assets
└── templates/               # Responsive HTML templates
```

---

## License

Internal instructional and training use.
