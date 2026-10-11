(() => {
  const data = JSON.parse(document.getElementById('page-data').textContent);
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const $ = (id) => document.getElementById(id);

  const post = (url, body) => fetch(url, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'X-CSRF-Token': csrf},
    body: JSON.stringify(body),
  }).then(r => r.json());

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));

  // ------------------------------------------------------------------ editor
  const starter = data.isSql
    ? `-- Q${data.number}: write your PostgreSQL query here\n`
    : `-- Q${data.number}: write your answer here (plain text is fine)\n`;
  const draftKey = `draft:${data.qid}`;
  let initial = data.initial || starter;
  try { initial = localStorage.getItem(draftKey) || initial; } catch (e) {}

  const editor = CodeMirror.fromTextArea($('editor'), {
    mode: 'text/x-pgsql',
    lineNumbers: true,
    matchBrackets: true,
    autoCloseBrackets: true,
    indentUnit: 2,
    tabSize: 2,
    lineWrapping: !data.isSql,
    extraKeys: {
      'Ctrl-Enter': () => run(),
      'Cmd-Enter': () => run(),
      'Ctrl-Space': 'autocomplete',
      'Ctrl-S': () => { save(); return false; },
      'Cmd-S': () => { save(); return false; },
    },
    hintOptions: {completeSingle: false, tables: {}},
  });
  editor.setValue(initial);
  editor.setCursor(editor.lineCount(), 0);
  editor.focus();

  // Local draft on every change, server save after a pause.
  let saveTimer = null;
  editor.on('change', () => {
    try { localStorage.setItem(draftKey, editor.getValue()); } catch (e) {}
    $('save-state').textContent = 'Unsaved';
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 2500);
  });

  function save() {
    clearTimeout(saveTimer);
    return post(data.urls.save, {sql: editor.getValue()}).then(() => {
      $('save-state').textContent = 'Saved';
      try { localStorage.removeItem(draftKey); } catch (e) {}
    }).catch(() => { $('save-state').textContent = 'Save failed'; });
  }

  // ------------------------------------------------------------------ result tabs
  function showTab(name) {
    document.querySelectorAll('.rtab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
    document.querySelectorAll('.rpanel').forEach(p => p.hidden = p.dataset.panel !== name);
  }
  document.querySelectorAll('.rtab').forEach(t => t.addEventListener('click', () => showTab(t.dataset.tab)));

  function setStatus(status) {
    const badge = $('status-badge');
    badge.className = `status-badge ${status}`;
    badge.textContent = status === 'solved' ? '✓ Solved' : status === 'attempted' ? 'In progress' : 'New';
    $('submit-btn').textContent = status === 'solved' ? 'Submit again' : 'Submit';
  }

  function showVerdict(kind, html) {
    const v = $('verdict');
    v.className = `verdict verdict-${kind}`;
    v.innerHTML = html;
    v.hidden = false;
  }

  // ------------------------------------------------------------------ run
  let running = false;
  function run() {
    if (running) return;
    const sel = editor.getSelection();
    const sql = sel.trim() ? sel : editor.getValue();
    running = true;
    const btn = $('run-btn');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Running…';
    $('run-meta').textContent = '';
    $('verdict').hidden = true;
    $('result-panel').innerHTML = '<div class="placeholder">Running query…</div>';
    showTab('result');

    post(data.urls.run, {sql})
      .then(renderResult)
      .catch(err => renderResult({ok: false, error: {message: `Request failed: ${err}`}, messages: []}))
      .finally(() => {
        running = false;
        btn.disabled = false;
        btn.innerHTML = '<span class="play">▶</span> Run <kbd>Ctrl ↵</kbd>';
        $('save-state').textContent = 'Saved';
        try { localStorage.removeItem(draftKey); } catch (e) {}
      });
  }
  $('run-btn').addEventListener('click', run);

  function renderResult(res) {
    const msgs = res.messages || [];
    $('messages-panel').innerHTML = msgs.length
      ? `<ul class="msg-list">${msgs.map(m => `<li>${escapeHtml(m)}</li>`).join('')}</ul>`
      : '<div class="placeholder">No messages.</div>';
    $('msg-count').textContent = msgs.length || '';

    if (res.status) setStatus(res.status);
    if (res.elapsed_ms !== undefined) $('run-meta').textContent = `${res.elapsed_ms} ms`;

    if (!res.ok) {
      const e = res.error || {};
      const parts = [`<div class="err-title">ERROR${e.sqlstate ? ` <code>${escapeHtml(e.sqlstate)}</code>` : ''}${e.statement_index > 1 ? ` in statement ${e.statement_index}` : ''}</div>`,
        `<div class="err-msg">${escapeHtml(e.message || 'Unknown error')}</div>`];
      if (e.detail) parts.push(`<div class="err-extra"><b>Detail:</b> ${escapeHtml(e.detail)}</div>`);
      if (e.hint) parts.push(`<div class="err-extra"><b>Hint:</b> ${escapeHtml(e.hint)}</div>`);
      $('result-panel').innerHTML = `<div class="error-box">${parts.join('')}</div>`;
      if (e.position && e.statement_index === 1) markErrorPosition(Number(e.position));
      return;
    }

    if (!res.columns) {
      const last = msgs.length ? msgs[msgs.length - 1] : 'OK';
      $('result-panel').innerHTML = `<div class="placeholder ok">✓ Executed successfully: <code>${escapeHtml(last)}</code><br><span class="muted small">Changes are rolled back after every run, so the shared database is never modified.</span></div>`;
    } else {
      const head = `<tr><th class="rownum">#</th>${res.columns.map(c => `<th>${escapeHtml(c)}</th>`).join('')}</tr>`;
      const body = res.rows.map((r, i) => `<tr><td class="rownum">${i + 1}</td>${r.map(cell).join('')}</tr>`).join('');
      const note = res.truncated ? `<div class="trunc">Showing first ${res.row_limit} rows.</div>` : '';
      $('result-panel').innerHTML = res.rows.length
        ? `<div class="grid-wrap"><table class="grid"><thead>${head}</thead><tbody>${body}</tbody></table></div>${note}`
        : `<div class="grid-wrap"><table class="grid"><thead>${head}</thead></table></div><div class="placeholder">0 rows returned.</div>`;
      $('run-meta').textContent = `${res.rows.length}${res.truncated ? '+' : ''} row${res.rows.length === 1 ? '' : 's'} · ${res.elapsed_ms} ms`;
    }

    // Running is only a test - Submit is what marks the question solved.
    const g = res.grade;
    if (g && g.verdict === 'correct') {
      showVerdict('info', '<b>Your result matches the expected output.</b> Click <b>Submit</b> to complete the question.');
    } else if (g && g.verdict === 'incorrect') {
      showVerdict('info', `Your result differs from the expected output (${escapeHtml(g.reason)}). If you think your query is still right, Submit it - the checker looks at the query itself too.`);
    }
  }

  function cell(v) {
    if (v === null) return '<td class="null">NULL</td>';
    if (typeof v === 'number') return `<td class="num">${v}</td>`;
    if (typeof v === 'boolean') return `<td class="bool">${v}</td>`;
    return `<td>${escapeHtml(v)}</td>`;
  }

  let errorMark = null;
  function markErrorPosition(pos) {
    // Postgres positions are 1-based character offsets into the statement we sent.
    const sel = editor.getSelection();
    const base = sel.trim() ? editor.indexFromPos(editor.getCursor('from')) : 0;
    const from = editor.posFromIndex(base + pos - 1);
    const to = editor.posFromIndex(base + pos + 8);
    if (errorMark) errorMark.clear();
    errorMark = editor.markText(from, to, {className: 'cm-error-mark'});
    editor.once('change', () => errorMark && errorMark.clear());
  }

  // ------------------------------------------------------------------ submit (accepted only when correct)
  let submitting = false;
  $('submit-btn').addEventListener('click', () => {
    if (submitting || running) return;
    submitting = true;
    const btn = $('submit-btn');
    const label = btn.textContent;
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Checking…';
    $('verdict').hidden = true;

    post(data.urls.submit, {sql: editor.getValue()})
      .then(r => {
        if (r.result) { renderResult(r.result); }
        if (r.status) setStatus(r.status);
        const feedback = escapeHtml(r.feedback || '');
        if (r.accepted) {
          const how = r.method === 'ai' ? ' <span class="muted small">(checked by AI)</span>' : '';
          const next = data.nextUrl ? ` <a href="${data.nextUrl}" class="btn btn-sm btn-success">Next question ›</a>` : '';
          showVerdict('correct', `<b>🎉 Accepted!</b> ${feedback}${how}${next}`);
        } else if (r.verdict === 'incorrect') {
          showVerdict('incorrect', `<b>Not accepted.</b> ${feedback}`);
        } else if (r.verdict === 'unavailable') {
          showVerdict('info', `<b>Couldn't check right now.</b> ${feedback}`);
        } else {
          showVerdict('incorrect', feedback);
        }
        if (!r.result) showTab('result');
        $('save-state').textContent = 'Saved';
        try { localStorage.removeItem(draftKey); } catch (e) {}
      })
      .catch(err => showVerdict('incorrect', `Submit failed: ${escapeHtml(String(err))}`))
      .finally(() => {
        submitting = false;
        btn.disabled = false;
        if (btn.querySelector('.spinner')) btn.textContent = label;
      });
  });

  // ------------------------------------------------------------------ answer key (behind a quick arithmetic check)
  const answerBtn = $('answer-btn');
  if (answerBtn) {
    const modal = $('reveal-modal');
    const input = $('challenge-input');
    let expected = null;

    function newChallenge() {
      const rand = (lo, hi) => lo + Math.floor(Math.random() * (hi - lo + 1));
      const kind = rand(0, 2);
      let a, b, text;
      if (kind === 0) { a = rand(11, 49); b = rand(11, 49); expected = a + b; text = `${a} + ${b}`; }
      else if (kind === 1) { a = rand(30, 90); b = rand(5, a - 10); expected = a - b; text = `${a} − ${b}`; }
      else { a = rand(3, 12); b = rand(3, 9); expected = a * b; text = `${a} × ${b}`; }
      $('challenge-text').textContent = `${text} =`;
      input.value = '';
      input.focus();
    }

    function openModal() {
      $('challenge-error').hidden = true;
      modal.hidden = false;
      newChallenge();
    }
    const closeModal = () => { modal.hidden = true; editor.focus(); };

    function revealAnswer() {
      post(data.urls.answer, {}).then(a => {
        const parts = [];
        if (a.text) parts.push(`<p class="answer-text">${escapeHtml(a.text)}</p>`);
        if (a.sql) parts.push(`<div class="answer-sql"><div class="answer-actions"><button class="btn btn-ghost btn-sm" id="copy-answer">Copy to editor</button></div><pre><code>${escapeHtml(a.sql)}</code></pre></div>`);
        $('answer-panel').innerHTML = parts.join('') || '<div class="placeholder">No answer key for this question.</div>';
        const copy = $('copy-answer');
        if (copy) copy.addEventListener('click', () => {
          editor.setValue(editor.getValue().replace(/\s*$/, '') + '\n\n-- Answer key\n' + a.sql + '\n');
          editor.focus();
        });
        $('answer-tab').hidden = false;
        showTab('answer');
      });
    }

    answerBtn.addEventListener('click', () => {
      if (!$('answer-tab').hidden) { showTab('answer'); return; }
      openModal();
    });

    $('reveal-form').addEventListener('submit', (e) => {
      e.preventDefault();
      if (Number(input.value.trim()) === expected && input.value.trim() !== '') {
        closeModal();
        revealAnswer();
      } else {
        $('challenge-error').hidden = false;
        modal.querySelector('.modal').classList.remove('shake');
        void modal.offsetWidth;
        modal.querySelector('.modal').classList.add('shake');
        newChallenge();
      }
    });
    $('reveal-cancel').addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !modal.hidden) closeModal(); });
  }

  // ------------------------------------------------------------------ schema browser
  let schemaLoaded = false;
  $('schema-btn').addEventListener('click', () => {
    const panel = $('schema-panel');
    panel.hidden = !panel.hidden;
    $('schema-btn').classList.toggle('active', !panel.hidden);
    editor.refresh();
    if (!panel.hidden && !schemaLoaded) loadSchema();
  });

  function loadSchema() {
    schemaLoaded = true;
    fetch(data.urls.schema).then(r => r.json()).then(tree => {
      if (tree.error) {
        $('schema-tree').innerHTML = `<p class="muted small pad">${escapeHtml(tree.error)}</p>`;
        schemaLoaded = false;
        return;
      }
      const hintTables = {};
      const html = Object.keys(tree).sort().map(schema => {
        const tables = Object.keys(tree[schema]).sort().map(t => {
          hintTables[`${schema}.${t}`] = tree[schema][t].map(c => c[0]);
          const cols = tree[schema][t].map(([c, ty]) => `<li><span class="col">${escapeHtml(c)}</span><span class="type">${escapeHtml(ty)}</span></li>`).join('');
          return `<details class="tbl" data-name="${escapeHtml((schema + '.' + t).toLowerCase())}"><summary><span class="tbl-name" data-insert="${escapeHtml(schema + '.' + t)}">${escapeHtml(t)}</span></summary><ul>${cols}</ul></details>`;
        }).join('');
        return `<details class="sch" open><summary>${escapeHtml(schema)}</summary>${tables}</details>`;
      }).join('');
      $('schema-tree').innerHTML = html || '<p class="muted small pad">No tables found.</p>';
      editor.setOption('hintOptions', {completeSingle: false, tables: hintTables});
    }).catch(() => { schemaLoaded = false; });
  }

  $('schema-tree').addEventListener('dblclick', (e) => {
    const target = e.target.closest('[data-insert], .col');
    if (!target) return;
    editor.replaceSelection(target.dataset.insert || target.textContent);
    editor.focus();
  });

  $('schema-filter').addEventListener('input', (e) => {
    const f = e.target.value.trim().toLowerCase();
    document.querySelectorAll('#schema-tree .tbl').forEach(t => { t.hidden = f && !t.dataset.name.includes(f); });
  });

  // ------------------------------------------------------------------ draggable splitter
  const split = $('split');
  const editorPane = $('editor-pane');
  const splitter = $('splitter');
  const ratioKey = 'split-ratio';
  const applyRatio = (r) => { editorPane.style.flex = `0 0 ${Math.min(85, Math.max(15, r * 100))}%`; editor.refresh(); };
  try { const saved = parseFloat(localStorage.getItem(ratioKey)); if (saved) applyRatio(saved); } catch (e) {}

  splitter.addEventListener('pointerdown', (e) => {
    splitter.setPointerCapture(e.pointerId);
    document.body.classList.add('dragging');
    const rect = split.getBoundingClientRect();
    const move = (ev) => applyRatio((ev.clientY - rect.top) / rect.height);
    const up = () => {
      splitter.removeEventListener('pointermove', move);
      splitter.removeEventListener('pointerup', up);
      document.body.classList.remove('dragging');
      try { localStorage.setItem(ratioKey, editorPane.getBoundingClientRect().height / rect.height); } catch (e) {}
    };
    splitter.addEventListener('pointermove', move);
    splitter.addEventListener('pointerup', up);
  });

  window.addEventListener('beforeunload', () => {
    if ($('save-state').textContent === 'Unsaved') {
      navigator.sendBeacon && fetch(data.urls.save, {
        method: 'POST', keepalive: true,
        headers: {'Content-Type': 'application/json', 'X-CSRF-Token': csrf},
        body: JSON.stringify({sql: editor.getValue()}),
      });
    }
  });
})();
