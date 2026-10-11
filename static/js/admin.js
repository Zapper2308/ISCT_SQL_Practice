(() => {
  const $ = (id) => document.getElementById(id);

  // ---------------------------------------------------------------- password reset links
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  document.querySelectorAll('.make-link').forEach(btn => btn.addEventListener('click', async () => {
    const li = btn.closest('li');
    btn.disabled = true;
    try {
      const r = await fetch(btn.dataset.url, {method: 'POST', headers: {'X-CSRF-Token': csrf}}).then(r => r.json());
      const box = li.querySelector('.reset-link-box');
      const input = box.querySelector('input');
      input.value = r.link;
      box.hidden = false;
      input.select();
      btn.textContent = 'New link';
    } finally {
      btn.disabled = false;
    }
  }));
  document.querySelectorAll('.copy-link').forEach(btn => btn.addEventListener('click', async () => {
    const input = btn.parentElement.querySelector('input');
    try { await navigator.clipboard.writeText(input.value); } catch (e) { input.select(); document.execCommand('copy'); }
    btn.textContent = 'Copied!';
    setTimeout(() => { btn.textContent = 'Copy'; }, 1500);
  }));

  // ---------------------------------------------------------------- students table: search + sort
  const students = $('students');
  if (students) {
    $('student-search').addEventListener('input', (e) => {
      const f = e.target.value.trim().toLowerCase();
      let shown = 0;
      students.querySelectorAll('tbody tr').forEach(tr => {
        tr.hidden = f && !tr.dataset.search.includes(f);
        shown += !tr.hidden;
      });
      $('no-match').hidden = shown > 0;
    });

    students.querySelectorAll('th[data-sort]').forEach((th, col) => {
      th.addEventListener('click', () => {
        const numeric = th.dataset.sort === 'num';
        const desc = th.classList.contains('sorted-asc') || (numeric && !th.classList.contains('sorted-desc'));
        students.querySelectorAll('th').forEach(h => h.classList.remove('sorted-asc', 'sorted-desc'));
        th.classList.add(desc ? 'sorted-desc' : 'sorted-asc');
        const tbody = students.tBodies[0];
        const key = (tr) => {
          const v = tr.cells[col].dataset.v ?? tr.cells[col].textContent;
          return numeric ? parseFloat(v) || 0 : v;
        };
        [...tbody.rows]
          .sort((a, b) => (key(a) > key(b) ? 1 : key(a) < key(b) ? -1 : 0) * (desc ? -1 : 1))
          .forEach(tr => tbody.appendChild(tr));
      });
    });
  }

  // ---------------------------------------------------------------- student history: filters + view SQL
  const history = $('history');
  if (history) {
    const apply = () => {
      const d = $('f-diff').value, s = $('f-status').value, t = $('f-text').value.trim().toLowerCase();
      let shown = 0;
      history.querySelectorAll('tr.h-row').forEach(tr => {
        const show = (!d || tr.dataset.diff === d) && (!s || tr.dataset.status === s) && (!t || tr.dataset.search.includes(t));
        tr.hidden = !show;
        const sqlRow = tr.nextElementSibling;
        if (sqlRow && sqlRow.classList.contains('sql-row') && !show) sqlRow.hidden = true;
        shown += show;
      });
      $('no-match').hidden = shown > 0;
    };
    ['f-diff', 'f-status', 'f-text'].forEach(id => $(id).addEventListener('input', apply));

    history.addEventListener('click', (e) => {
      const btn = e.target.closest('.toggle-sql');
      if (!btn) return;
      const sqlRow = btn.closest('tr').nextElementSibling;
      sqlRow.hidden = !sqlRow.hidden;
      btn.textContent = sqlRow.hidden ? 'View answer' : 'Hide answer';
    });
  }
})();
