"""Parses the Practice/ question files and answer keys into an in-memory bank.

Layout expected:
  Practice/retailmart_v3/<NN-topic>/<NN-topic>_<difficulty>.sql
  Practice/retailmart_v3_answer_keys/<NN-topic>/<NN-topic>_<difficulty>_answers.sql
"""
import os
import re
from dataclasses import dataclass, field

DIFFICULTIES = ["easy", "medium", "hard", "crazy"]

FILE_RE = re.compile(r"^(\d+)-(.+)_(easy|medium|hard|crazy)\.sql$")
SECTION_RE = re.compile(r"SECTION\s+([A-Z])\s*:\s*(.+?)\s*(?:\((\d+)\))?\s*$", re.M)
QUESTION_RE = re.compile(r"/\*\s*Q(\d+)\.\s*(.*?)\s*\*/", re.S)
ANSWER_START_RE = re.compile(r"^/\*\s*Q(\d+)\.", re.M)
BANNER_RE = re.compile(r"/\*\s*=+.*?\*/", re.S)
TITLE_RE = re.compile(r"SQL PRACTICE SET\s*-\s*(.+?)\s*\((?:EASY|MEDIUM|HARD|CRAZY) LEVEL\)")


@dataclass
class Question:
    id: str                # e.g. "05-medium-26"
    number: int
    text: str
    topic_slug: str
    difficulty: str
    section: str           # "A"
    answer_text: str = ""  # explanation / conceptual answer (comment text)
    answer_sql: str = ""   # executable reference SQL, if any

    @property
    def is_sql(self) -> bool:
        return bool(self.answer_sql.strip())


@dataclass
class Section:
    letter: str
    title: str
    questions: list = field(default_factory=list)


@dataclass
class Topic:
    slug: str              # "05-filtering-sorting"
    order: int
    title: str             # "Filtering & Sorting"
    sections: dict = field(default_factory=dict)   # difficulty -> list[Section]

    def questions(self, difficulty):
        return [q for s in self.sections.get(difficulty, []) for q in s.questions]


def _parse_questions(text):
    """Yields (section_letter, section_title, number, question_text) in file order."""
    markers = [(m.start(), m.group(1), m.group(2).strip()) for m in SECTION_RE.finditer(text)]
    for m in QUESTION_RE.finditer(text):
        letter, title = "A", "Questions"
        for start, sec_letter, sec_title in markers:
            if start <= m.start():
                letter, title = sec_letter, sec_title
        q_text = re.sub(r"\s*\n\s*", " ", m.group(2)).strip()
        yield letter, title, int(m.group(1)), q_text


def _parse_answers(text):
    """Returns {number: (answer_text, answer_sql)}.

    Each answer starts with a `/* Qn. ... */` comment; anything after the comment
    up to the next answer is the reference SQL (section banners stripped).
    """
    answers = {}
    starts = list(ANSWER_START_RE.finditer(text))
    for i, m in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
        chunk = text[m.start():end]
        close = chunk.find("*/")
        comment = re.sub(r"^/\*\s*Q\d+\.\s*", "", chunk[:close]).strip()
        comment = re.sub(r"\s*\n\s*", " ", comment)
        sql = BANNER_RE.sub("", chunk[close + 2:]).strip()
        answers[int(m.group(1))] = (comment, sql)
    return answers


class QuestionBank:
    def __init__(self, practice_dir):
        self.topics = []          # ordered list[Topic]
        self.topic_by_slug = {}
        self.questions = {}       # qid -> Question
        self._load(practice_dir)
        self.totals = {d: sum(len(t.questions(d)) for t in self.topics) for d in DIFFICULTIES}

    def _load(self, practice_dir):
        q_root = os.path.join(practice_dir, "retailmart_v3")
        a_root = os.path.join(practice_dir, "retailmart_v3_answer_keys")
        if not os.path.isdir(q_root):
            raise FileNotFoundError(f"Question folder not found: {q_root}")

        for topic_dir in sorted(os.listdir(q_root)):
            tpath = os.path.join(q_root, topic_dir)
            if not os.path.isdir(tpath):
                continue
            for fname in sorted(os.listdir(tpath)):
                fm = FILE_RE.match(fname)
                if not fm:
                    continue
                order, diff = int(fm.group(1)), fm.group(3)
                with open(os.path.join(tpath, fname), encoding="utf-8") as f:
                    qtext = f.read()

                topic = self.topic_by_slug.get(topic_dir)
                if topic is None:
                    tm = TITLE_RE.search(qtext)
                    title = tm.group(1).strip() if tm else topic_dir.split("-", 1)[1].replace("-", " ").title()
                    topic = Topic(slug=topic_dir, order=order, title=title)
                    self.topic_by_slug[topic_dir] = topic

                answers = {}
                ans_path = os.path.join(a_root, topic_dir, fname[:-4] + "_answers.sql")
                if os.path.exists(ans_path):
                    with open(ans_path, encoding="utf-8") as f:
                        answers = _parse_answers(f.read())

                sections = {}
                for letter, stitle, num, text in _parse_questions(qtext):
                    sec = sections.setdefault(letter, Section(letter=letter, title=stitle))
                    a_text, a_sql = answers.get(num, ("", ""))
                    q = Question(id=f"{order:02d}-{diff}-{num}", number=num, text=text,
                                 topic_slug=topic_dir, difficulty=diff, section=letter,
                                 answer_text=a_text, answer_sql=a_sql)
                    sec.questions.append(q)
                    self.questions[q.id] = q
                topic.sections[diff] = list(sections.values())

        self.topics = sorted(self.topic_by_slug.values(), key=lambda t: t.order)

    def neighbours(self, q):
        """Previous / next question within the same topic + difficulty."""
        siblings = self.topic_by_slug[q.topic_slug].questions(q.difficulty)
        idx = next(i for i, s in enumerate(siblings) if s.id == q.id)
        prev_q = siblings[idx - 1] if idx > 0 else None
        next_q = siblings[idx + 1] if idx + 1 < len(siblings) else None
        return prev_q, next_q
