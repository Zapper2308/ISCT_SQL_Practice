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

  // ------------------------------------------------------------------ database tree explorer (pgAdmin 4 style)
  const schemaPanel = $('schema-panel');
  const schemaResizer = $('schema-resizer');
  const schemaTree = $('schema-tree');
  const schemaSearchInput = $('schema-search-input');
  const schemaSearchClear = $('schema-search-clear');
  const schemaSearchStats = $('schema-search-stats');
  const schemaDbName = $('schema-db-name');
  const schemaToggleBtn = $('schema-toggle-btn');
  const schemaBtn = $('schema-btn');
  const schemaRefreshBtn = $('schema-refresh-btn');
  const schemaCollapseBtn = $('schema-collapse-btn');

  let rawSchemaData = null;
  let schemaLoaded = false;

  // Restore panel width and state from localStorage
  try {
    const savedWidth = localStorage.getItem('schema-panel-width');
    if (savedWidth && schemaPanel) schemaPanel.style.width = savedWidth;
    const isCollapsed = localStorage.getItem('schema-panel-collapsed') === 'true';
    if (isCollapsed && schemaPanel) {
      schemaPanel.classList.add('collapsed');
      if (schemaBtn) schemaBtn.classList.remove('active');
    }
  } catch (e) {}

  // Toggle button handlers
  const togglePanel = (forceState) => {
    if (!schemaPanel) return;
    const shouldCollapse = forceState !== undefined ? !forceState : !schemaPanel.classList.contains('collapsed');
    schemaPanel.classList.toggle('collapsed', shouldCollapse);
    if (schemaBtn) schemaBtn.classList.toggle('active', !shouldCollapse);
    try { localStorage.setItem('schema-panel-collapsed', shouldCollapse); } catch (e) {}
    editor.refresh();
  };

  if (schemaBtn) schemaBtn.addEventListener('click', () => togglePanel());
  if (schemaToggleBtn) schemaToggleBtn.addEventListener('click', () => togglePanel(false));

  // Resizer for Database Explorer panel
  if (schemaResizer && schemaPanel) {
    schemaResizer.addEventListener('pointerdown', (e) => {
      schemaResizer.setPointerCapture(e.pointerId);
      document.body.classList.add('resizing-schema');
      const startX = e.clientX;
      const startWidth = schemaPanel.getBoundingClientRect().width;

      const onPointerMove = (ev) => {
        const newWidth = Math.min(650, Math.max(220, startWidth + (ev.clientX - startX)));
        schemaPanel.style.width = `${newWidth}px`;
        editor.refresh();
      };

      const onPointerUp = (ev) => {
        schemaResizer.releasePointerCapture(ev.pointerId);
        document.body.classList.remove('resizing-schema');
        schemaResizer.removeEventListener('pointermove', onPointerMove);
        schemaResizer.removeEventListener('pointerup', onPointerUp);
        try { localStorage.setItem('schema-panel-width', schemaPanel.style.width); } catch (e) {}
        editor.refresh();
      };

      schemaResizer.addEventListener('pointermove', onPointerMove);
      schemaResizer.addEventListener('pointerup', onPointerUp);
    });
  }

  // Load Schema
  function loadSchema(forceRefresh = false) {
    if (forceRefresh) {
      schemaTree.innerHTML = '<div class="schema-loading"><span class="spinner"></span> Refreshing database explorer…</div>';
    }
    const url = forceRefresh ? `${data.urls.schema}?refresh=1` : data.urls.schema;
    fetch(url)
      .then(r => r.json())
      .then(tree => {
        if (tree.error) {
          schemaTree.innerHTML = `<p class="muted small pad" style="padding: 16px;">${escapeHtml(tree.error)}</p>`;
          return;
        }
        rawSchemaData = tree;
        schemaLoaded = true;
        renderDatabaseTree(tree);
      })
      .catch(err => {
        schemaTree.innerHTML = `<p class="muted small pad" style="padding: 16px;">Could not connect to database explorer.</p>`;
      });
  }

  // Render Full pgAdmin 4 Style Tree
  function renderDatabaseTree(tree) {
    const dbName = tree.database || 'Database';
    if (schemaDbName) schemaDbName.textContent = dbName;

    const schemas = tree.schemas || {};
    const schemaNames = Object.keys(schemas).sort();

    const hintTables = {};

    let html = '';
    html += `<details class="tree-node tree-root" open>`;
    html += `<summary><span class="node-icon">🗄️</span> <span class="node-name searchable-text" data-text="${escapeHtml(dbName)}">${escapeHtml(dbName)}</span> <span class="node-badge">${schemaNames.length} schemas</span></summary>`;
    html += `<div class="tree-children">`;

    schemaNames.forEach(schName => {
      const sch = schemas[schName];
      const tableNames = Object.keys(sch.tables || {}).sort();
      const viewNames = Object.keys(sch.views || {}).sort();
      const totalRels = tableNames.length + viewNames.length;

      html += `<details class="tree-node tree-schema" data-search-container open>`;
      html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="${escapeHtml(schName)}">${escapeHtml(schName)}</span> <span class="node-badge">${totalRels}</span></summary>`;
      html += `<div class="tree-children">`;

      // Tables Folder
      if (tableNames.length > 0) {
        html += `<details class="tree-node tree-folder" data-search-container open>`;
        html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Tables">Tables</span> <span class="node-badge">${tableNames.length}</span></summary>`;
        html += `<div class="tree-children">`;

        tableNames.forEach(tblName => {
          const tbl = sch.tables[tblName];
          const cols = tbl.columns || [];
          const cons = tbl.constraints || [];
          const idxs = tbl.indexes || [];
          const rules = tbl.rules || [];
          const trigs = tbl.triggers || [];

          // Autocomplete hints
          hintTables[`${schName}.${tblName}`] = cols.map(c => c.name);

          html += `<details class="tree-node tree-table" data-search-container data-insert="${escapeHtml(schName + '.' + tblName)}">`;
          html += `<summary>
            <span class="node-icon">📄</span>
            <span class="node-name searchable-text" data-text="${escapeHtml(tblName)}" data-insert="${escapeHtml(schName + '.' + tblName)}" title="Double-click to insert table">${escapeHtml(tblName)}</span>
            <button type="button" class="copy-pill" data-copy="${escapeHtml(schName + '.' + tblName)}" title="Copy full table name">📋</button>
          </summary>`;
          html += `<div class="tree-children">`;

          // Columns
          html += `<details class="tree-node tree-subfolder" data-search-container open>`;
          html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Columns">Columns</span> <span class="node-badge">${cols.length}</span></summary>`;
          html += `<ul class="tree-leaf-list">`;
          cols.forEach(col => {
            html += `<li class="tree-leaf-item" data-search-item data-insert="${escapeHtml(col.name)}" title="${escapeHtml(col.name)}: ${escapeHtml(col.type)}">
              <div class="leaf-left">
                <span class="leaf-icon">${col.is_pk ? '🔑' : '🔹'}</span>
                <span class="leaf-name searchable-text" data-text="${escapeHtml(col.name)}" data-insert="${escapeHtml(col.name)}" title="Double-click to insert">${escapeHtml(col.name)}</span>
                ${col.is_pk ? '<span class="badge-pk" title="Primary Key">PK</span>' : ''}
                ${!col.nullable ? '<span class="badge-nn" title="Not Null">NN</span>' : ''}
                <button type="button" class="copy-pill" data-copy="${escapeHtml(col.name)}" title="Copy column name">📋</button>
              </div>
              <span class="leaf-type searchable-text" data-text="${escapeHtml(col.type)}">${escapeHtml(col.type)}</span>
            </li>`;
          });
          html += `</ul></details>`;

          // Constraints
          if (cons.length > 0) {
            html += `<details class="tree-node tree-subfolder" data-search-container>`;
            html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Constraints">Constraints</span> <span class="node-badge">${cons.length}</span></summary>`;
            html += `<ul class="tree-leaf-list">`;
            cons.forEach(con => {
              const conClass = 'badge-' + (con.type || '').toLowerCase().replace(/\s+/g, '-');
              html += `<li class="tree-leaf-item" data-search-item title="${escapeHtml(con.definition || '')}">
                <div class="leaf-left">
                  <span class="leaf-icon">🔒</span>
                  <span class="leaf-name searchable-text" data-text="${escapeHtml(con.name)}">${escapeHtml(con.name)}</span>
                </div>
                <span class="badge-con ${conClass} searchable-text" data-text="${escapeHtml(con.type)}">${escapeHtml(con.type)}</span>
              </li>`;
            });
            html += `</ul></details>`;
          }

          // Indexes
          if (idxs.length > 0) {
            html += `<details class="tree-node tree-subfolder" data-search-container>`;
            html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Indexes">Indexes</span> <span class="node-badge">${idxs.length}</span></summary>`;
            html += `<ul class="tree-leaf-list">`;
            idxs.forEach(idx => {
              html += `<li class="tree-leaf-item" data-search-item title="${escapeHtml(idx.definition || '')}">
                <div class="leaf-left">
                  <span class="leaf-icon">⚡</span>
                  <span class="leaf-name searchable-text" data-text="${escapeHtml(idx.name)}">${escapeHtml(idx.name)}</span>
                  ${idx.is_unique ? '<span class="idx-badge">UNIQUE</span>' : ''}
                </div>
              </li>`;
            });
            html += `</ul></details>`;
          }

          // Rules
          if (rules.length > 0) {
            html += `<details class="tree-node tree-subfolder" data-search-container>`;
            html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Rules">Rules</span> <span class="node-badge">${rules.length}</span></summary>`;
            html += `<ul class="tree-leaf-list">`;
            rules.forEach(r => {
              html += `<li class="tree-leaf-item" data-search-item title="${escapeHtml(r.definition || '')}">
                <div class="leaf-left">
                  <span class="leaf-icon">⚙️</span>
                  <span class="leaf-name searchable-text" data-text="${escapeHtml(r.name)}">${escapeHtml(r.name)}</span>
                </div>
              </li>`;
            });
            html += `</ul></details>`;
          }

          // Triggers
          if (trigs.length > 0) {
            html += `<details class="tree-node tree-subfolder" data-search-container>`;
            html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Triggers">Triggers</span> <span class="node-badge">${trigs.length}</span></summary>`;
            html += `<ul class="tree-leaf-list">`;
            trigs.forEach(tg => {
              html += `<li class="tree-leaf-item" data-search-item title="${escapeHtml(tg.definition || '')}">
                <div class="leaf-left">
                  <span class="leaf-icon">⚡</span>
                  <span class="leaf-name searchable-text" data-text="${escapeHtml(tg.name)}">${escapeHtml(tg.name)}</span>
                </div>
              </li>`;
            });
            html += `</ul></details>`;
          }

          html += `</div></details>`; // End table
        });
        html += `</div></details>`; // End tables folder
      }

      // Views Folder
      if (viewNames.length > 0) {
        html += `<details class="tree-node tree-folder" data-search-container open>`;
        html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Views">Views</span> <span class="node-badge">${viewNames.length}</span></summary>`;
        html += `<div class="tree-children">`;

        viewNames.forEach(viewName => {
          const vw = sch.views[viewName];
          const cols = vw.columns || [];

          hintTables[`${schName}.${viewName}`] = cols.map(c => c.name);

          html += `<details class="tree-node tree-view" data-search-container data-insert="${escapeHtml(schName + '.' + viewName)}">`;
          html += `<summary>
            <span class="node-icon">👁️</span>
            <span class="node-name searchable-text" data-text="${escapeHtml(viewName)}" data-insert="${escapeHtml(schName + '.' + viewName)}" title="Double-click to insert view">${escapeHtml(viewName)}</span>
            <button type="button" class="copy-pill" data-copy="${escapeHtml(schName + '.' + viewName)}" title="Copy full view name">📋</button>
          </summary>`;
          html += `<div class="tree-children">`;

          // Columns
          html += `<details class="tree-node tree-subfolder" data-search-container open>`;
          html += `<summary><span class="node-icon">📁</span> <span class="node-name searchable-text" data-text="Columns">Columns</span> <span class="node-badge">${cols.length}</span></summary>`;
          html += `<ul class="tree-leaf-list">`;
          cols.forEach(col => {
            html += `<li class="tree-leaf-item" data-search-item data-insert="${escapeHtml(col.name)}" title="${escapeHtml(col.name)}: ${escapeHtml(col.type)}">
              <div class="leaf-left">
                <span class="leaf-icon">🔹</span>
                <span class="leaf-name searchable-text" data-text="${escapeHtml(col.name)}" data-insert="${escapeHtml(col.name)}" title="Double-click to insert">${escapeHtml(col.name)}</span>
              </div>
              <span class="leaf-type searchable-text" data-text="${escapeHtml(col.type)}">${escapeHtml(col.type)}</span>
            </li>`;
          });
          html += `</ul></details>`;

          html += `</div></details>`; // End view
        });
        html += `</div></details>`; // End views folder
      }

      html += `</div></details>`; // End schema
    });

    html += `</div></details>`; // End database root

    schemaTree.innerHTML = html;
    editor.setOption('hintOptions', {completeSingle: false, tables: hintTables});
  }

  // pgAdmin 4 Style Search Engine
  function performSearch(query) {
    const q = query.trim().toLowerCase();
    const searchables = schemaTree.querySelectorAll('.searchable-text');

    if (!q) {
      if (schemaSearchClear) schemaSearchClear.hidden = true;
      if (schemaSearchStats) schemaSearchStats.hidden = true;
      searchables.forEach(el => {
        el.innerHTML = escapeHtml(el.dataset.text || el.textContent);
      });
      schemaTree.querySelectorAll('.search-hidden').forEach(el => el.classList.remove('search-hidden'));
      return;
    }

    if (schemaSearchClear) schemaSearchClear.hidden = false;
    if (schemaSearchStats) schemaSearchStats.hidden = false;

    let matchCount = 0;
    const matchedContainers = new Set();

    searchables.forEach(el => {
      const text = el.dataset.text || el.textContent;
      const lower = text.toLowerCase();
      const idx = lower.indexOf(q);

      if (idx !== -1) {
        matchCount++;
        // Highlight matching text
        const before = escapeHtml(text.slice(0, idx));
        const match = escapeHtml(text.slice(idx, idx + q.length));
        const after = escapeHtml(text.slice(idx + q.length));
        el.innerHTML = `${before}<mark class="search-match">${match}</mark>${after}`;

        // Mark all parent containers as matched
        let parent = el.closest('[data-search-container], .tree-node, [data-search-item]');
        while (parent && parent !== schemaTree) {
          matchedContainers.add(parent);
          if (parent.tagName === 'DETAILS') {
            parent.open = true;
          }
          parent = parent.parentElement ? parent.parentElement.closest('[data-search-container], .tree-node') : null;
        }
      } else {
        el.innerHTML = escapeHtml(text);
      }
    });

    // Update stats counter
    if (schemaSearchStats) {
      schemaSearchStats.textContent = matchCount === 0
        ? 'No matches found'
        : `${matchCount} match${matchCount === 1 ? '' : 'es'} found`;
    }

    // Hide non-matching items and containers
    const allContainers = schemaTree.querySelectorAll('[data-search-container], [data-search-item]');
    allContainers.forEach(el => {
      if (matchedContainers.has(el)) {
        el.classList.remove('search-hidden');
      } else {
        el.classList.add('search-hidden');
      }
    });
  }

  // Search input listeners
  if (schemaSearchInput) {
    schemaSearchInput.addEventListener('input', (e) => {
      performSearch(e.target.value);
    });
    schemaSearchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        schemaSearchInput.value = '';
        performSearch('');
        schemaSearchInput.blur();
      }
    });
  }

  if (schemaSearchClear) {
    schemaSearchClear.addEventListener('click', () => {
      if (schemaSearchInput) {
        schemaSearchInput.value = '';
        performSearch('');
        schemaSearchInput.focus();
      }
    });
  }

  // Refresh and Collapse All Buttons
  if (schemaRefreshBtn) {
    schemaRefreshBtn.addEventListener('click', () => loadSchema(true));
  }
  if (schemaCollapseBtn) {
    schemaCollapseBtn.addEventListener('click', () => {
      schemaTree.querySelectorAll('.tree-node').forEach(node => {
        if (!node.classList.contains('tree-root')) node.open = false;
      });
    });
  }

  // Double click and Copy button delegation
  schemaTree.addEventListener('dblclick', (e) => {
    const target = e.target.closest('[data-insert]');
    if (!target) return;
    editor.replaceSelection(target.dataset.insert || target.textContent);
    editor.focus();
  });

  schemaTree.addEventListener('click', (e) => {
    const copyBtn = e.target.closest('.copy-pill');
    if (!copyBtn) return;
    e.stopPropagation();
    e.preventDefault();
    const text = copyBtn.dataset.copy;
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
      const orig = copyBtn.textContent;
      copyBtn.textContent = '✓';
      setTimeout(() => { copyBtn.textContent = orig; }, 1200);
    });
  });

  // ------------------------------------------------------------------ ERD Engine (PostgreSQL / pgAdmin 4 Style)
  const erdBtn = $('schema-erd-btn');
  const erdModal = $('erd-modal');
  const erdWindow = $('erd-window');
  const erdCloseBtn = $('erd-close-btn');
  const erdMaximizeBtn = $('erd-maximize-btn');
  const erdSchemaSelect = $('erd-schema-select');
  const erdSearchInput = $('erd-search-input');
  const erdZoomIn = $('erd-zoom-in');
  const erdZoomOut = $('erd-zoom-out');
  const erdZoomFit = $('erd-zoom-fit');
  const erdAutoArrange = $('erd-auto-arrange');
  const erdZoomLevel = $('erd-zoom-level');
  const erdViewport = $('erd-viewport');
  const erdCanvas = $('erd-canvas');
  const erdSvgLayer = $('erd-svg-layer');
  const erdLinksGroup = $('erd-links-group');
  const erdNodesLayer = $('erd-nodes-layer');
  const erdDbName = $('erd-db-name');
  const erdCountTables = $('erd-count-tables');
  const erdCountColumns = $('erd-count-columns');
  const erdCountLinks = $('erd-count-links');

  let erdZoom = 1;
  let erdPanX = 60;
  let erdPanY = 60;
  let erdPositions = {};
  let erdTables = [];
  let erdLinks = [];

  function updateErdTransform() {
    if (!erdCanvas) return;
    erdCanvas.style.transform = `translate(${erdPanX}px, ${erdPanY}px) scale(${erdZoom})`;
    if (erdZoomLevel) erdZoomLevel.textContent = `${Math.round(erdZoom * 100)}%`;
  }

  function openERD() {
    if (!erdModal) return;
    erdModal.hidden = false;
    document.body.style.overflow = 'hidden';
    if (!rawSchemaData) {
      loadSchema();
      const poll = setInterval(() => {
        if (rawSchemaData) {
          clearInterval(poll);
          buildAndRenderERD();
        }
      }, 150);
    } else {
      buildAndRenderERD();
    }
  }

  function closeERD() {
    if (!erdModal) return;
    erdModal.hidden = true;
    document.body.style.overflow = '';
  }

  if (erdBtn) erdBtn.addEventListener('click', openERD);
  if (erdCloseBtn) erdCloseBtn.addEventListener('click', closeERD);
  if (erdModal) {
    erdModal.addEventListener('click', (e) => {
      if (e.target === erdModal) closeERD();
    });
  }
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && erdModal && !erdModal.hidden) {
      closeERD();
    }
  });
  if (erdMaximizeBtn && erdWindow) {
    erdMaximizeBtn.addEventListener('click', () => {
      erdWindow.classList.toggle('maximized');
      setTimeout(fitERDToScreen, 150);
    });
  }

  function buildAndRenderERD(resetPositions = false) {
    if (!rawSchemaData || !erdNodesLayer || !erdLinksGroup) return;

    if (erdDbName) erdDbName.textContent = rawSchemaData.database || 'Database';

    const schemas = rawSchemaData.schemas || {};
    const schemaNames = Object.keys(schemas).sort();
    if (erdSchemaSelect && erdSchemaSelect.options.length <= 1) {
      schemaNames.forEach(s => {
        const opt = document.createElement('option');
        opt.value = s;
        opt.textContent = `${s} (${Object.keys(schemas[s].tables || {}).length} tables)`;
        erdSchemaSelect.appendChild(opt);
      });
    }

    const currentSchemaFilter = erdSchemaSelect ? erdSchemaSelect.value : 'all';
    const searchQuery = erdSearchInput ? erdSearchInput.value.trim().toLowerCase() : '';

    erdTables = [];
    schemaNames.forEach(s => {
      const tbls = schemas[s].tables || {};
      Object.keys(tbls).forEach(t => {
        const tblData = tbls[t];
        erdTables.push({
          id: `${s}.${t}`,
          schema: s,
          name: t,
          columns: tblData.columns || [],
          constraints: tblData.constraints || []
        });
      });
    });

    const rawRels = rawSchemaData.relationships || [];
    erdLinks = rawRels.map(r => ({
      name: r.name,
      srcId: `${r.source_schema}.${r.source_table}`,
      tgtId: `${r.target_schema}.${r.target_table}`,
      srcCol: r.source_column,
      tgtCol: r.target_column,
    }));

    let visibleTables = erdTables;
    if (currentSchemaFilter !== 'all') {
      const relevantIds = new Set();
      erdTables.forEach(t => {
        if (t.schema === currentSchemaFilter) relevantIds.add(t.id);
      });
      erdLinks.forEach(l => {
        if (relevantIds.has(l.srcId)) relevantIds.add(l.tgtId);
        if (relevantIds.has(l.tgtId)) relevantIds.add(l.srcId);
      });
      visibleTables = erdTables.filter(t => relevantIds.has(t.id));
    }

    if (searchQuery) {
      visibleTables = visibleTables.filter(t => {
        return t.name.toLowerCase().includes(searchQuery) ||
               t.schema.toLowerCase().includes(searchQuery) ||
               t.columns.some(c => c.name.toLowerCase().includes(searchQuery));
      });
    }

    const visibleIds = new Set(visibleTables.map(t => t.id));
    const visibleLinks = erdLinks.filter(l => visibleIds.has(l.srcId) && visibleIds.has(l.tgtId));

    if (erdCountTables) erdCountTables.textContent = visibleTables.length;
    if (erdCountColumns) erdCountColumns.textContent = visibleTables.reduce((acc, t) => acc + t.columns.length, 0);
    if (erdCountLinks) erdCountLinks.textContent = visibleLinks.length;

    if (resetPositions || Object.keys(erdPositions).length === 0) {
      arrangeTableLayout(visibleTables);
    } else {
      let nextCol = 0, nextRow = 0;
      visibleTables.forEach((t) => {
        if (!erdPositions[t.id]) {
          erdPositions[t.id] = { x: 50 + nextCol * 360, y: 50 + nextRow * 320 };
          nextCol++;
          if (nextCol > 3) { nextCol = 0; nextRow++; }
        }
      });
    }

    erdNodesLayer.innerHTML = '';
    visibleTables.forEach(tbl => {
      const pos = erdPositions[tbl.id] || { x: 60, y: 60 };
      const card = document.createElement('div');
      card.className = 'erd-table-card';
      card.id = `erd-node-${tbl.id.replace(/\./g, '__')}`;
      card.dataset.tableId = tbl.id;
      card.style.left = `${pos.x}px`;
      card.style.top = `${pos.y}px`;

      let colsHtml = '';
      tbl.columns.forEach(c => {
        const isPk = Boolean(c.is_pk);
        const isFk = Boolean(c.is_fk);
        const rowClass = isPk ? 'is-pk' : (isFk ? 'is-fk' : '');
        const fkTitle = c.fk_to ? `References ${c.fk_to}` : (isPk ? 'Primary Key' : '');
        colsHtml += `
          <div class="erd-card-row ${rowClass}" data-col-name="${escapeHtml(c.name)}" title="${escapeHtml(fkTitle)}">
            <span class="erd-col-name">
              ${isPk ? '<span class="badge-pk-icon" title="Primary Key">🔑</span>' : (isFk ? '<span class="badge-fk-icon" title="Foreign Key">🔗</span>' : '')}
              <span>${escapeHtml(c.name)}</span>
            </span>
            <span class="erd-col-type">${escapeHtml(c.type || '')}</span>
          </div>`;
      });

      card.innerHTML = `
        <div class="erd-card-header">
          <div class="erd-card-title" title="${escapeHtml(tbl.id)}">
            <span class="tbl-icon">🗃️</span> ${escapeHtml(tbl.name)}
          </div>
          <span class="erd-card-schema">${escapeHtml(tbl.schema)}</span>
        </div>
        <div class="erd-card-body">
          ${colsHtml}
        </div>`;

      setupTableDrag(card, tbl.id);

      card.addEventListener('mouseenter', () => highlightConnected(tbl.id));
      card.addEventListener('mouseleave', () => clearHighlight());

      card.addEventListener('dblclick', (e) => {
        const colRow = e.target.closest('.erd-card-row');
        const textToInsert = colRow ? colRow.dataset.colName : `${tbl.schema}.${tbl.name}`;
        editor.replaceSelection(textToInsert);
        editor.focus();
      });

      erdNodesLayer.appendChild(card);
    });

    renderSvgLinks(visibleLinks);

    if (resetPositions) {
      setTimeout(fitERDToScreen, 50);
    }
  }

  function arrangeTableLayout(tables) {
    erdPositions = {};
    const cols = Math.max(2, Math.ceil(Math.sqrt(tables.length * 1.4)));
    const colWidth = 360;
    const rowHeight = 330;
    tables.forEach((t, i) => {
      const colIdx = i % cols;
      const rowIdx = Math.floor(i / cols);
      erdPositions[t.id] = {
        x: 60 + colIdx * colWidth,
        y: 60 + rowIdx * rowHeight
      };
    });
  }

  function renderSvgLinks(links) {
    if (!erdLinksGroup) return;
    erdLinksGroup.innerHTML = '';
    links.forEach((l, index) => {
      const srcNode = $(`erd-node-${l.srcId.replace(/\./g, '__')}`);
      const tgtNode = $(`erd-node-${l.tgtId.replace(/\./g, '__')}`);
      if (!srcNode || !tgtNode) return;

      const srcPos = erdPositions[l.srcId] || { x: 0, y: 0 };
      const tgtPos = erdPositions[l.tgtId] || { x: 0, y: 0 };
      const cardWidth = 270;

      let srcY = srcPos.y + 70;
      let tgtY = tgtPos.y + 70;
      const srcColElem = srcNode.querySelector(`[data-col-name="${l.srcCol}"]`);
      const tgtColElem = tgtNode.querySelector(`[data-col-name="${l.tgtCol}"]`);
      if (srcColElem) srcY = srcPos.y + srcColElem.offsetTop + 12;
      if (tgtColElem) tgtY = tgtPos.y + tgtColElem.offsetTop + 12;

      let srcX = srcPos.x + cardWidth;
      let tgtX = tgtPos.x;
      if (tgtPos.x < srcPos.x) {
        srcX = srcPos.x;
        tgtX = tgtPos.x + cardWidth;
      }

      const dx = Math.max(50, Math.abs(tgtX - srcX) * 0.45);
      const c1x = srcX + (tgtX >= srcX ? dx : -dx);
      const c2x = tgtX + (tgtX >= srcX ? -dx : dx);

      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', `M ${srcX} ${srcY} C ${c1x} ${srcY}, ${c2x} ${tgtY}, ${tgtX} ${tgtY}`);
      path.setAttribute('class', 'erd-link-line');
      path.setAttribute('data-src', l.srcId);
      path.setAttribute('data-tgt', l.tgtId);
      path.setAttribute('data-link-id', `link-${index}`);
      path.setAttribute('marker-start', 'url(#erd-dot)');
      path.setAttribute('marker-end', 'url(#erd-arrow)');

      const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
      title.textContent = `${l.srcId}(${l.srcCol}) → ${l.tgtId}(${l.tgtCol})`;
      path.appendChild(title);

      path.addEventListener('mouseenter', () => {
        path.classList.add('active');
        highlightNode(l.srcId);
        highlightNode(l.tgtId);
      });
      path.addEventListener('mouseleave', () => {
        path.classList.remove('active');
        clearHighlight();
      });

      erdLinksGroup.appendChild(path);
    });
  }

  function updateLinksForTable(tableId) {
    if (!erdLinksGroup) return;
    const visibleLinks = erdLinks.filter(l => (l.srcId === tableId || l.tgtId === tableId) && erdPositions[l.srcId] && erdPositions[l.tgtId]);

    visibleLinks.forEach(l => {
      const srcNode = $(`erd-node-${l.srcId.replace(/\./g, '__')}`);
      const tgtNode = $(`erd-node-${l.tgtId.replace(/\./g, '__')}`);
      if (!srcNode || !tgtNode) return;

      const path = erdLinksGroup.querySelector(`.erd-link-line[data-src="${l.srcId}"][data-tgt="${l.tgtId}"]`);
      if (!path) return;

      const srcPos = erdPositions[l.srcId];
      const tgtPos = erdPositions[l.tgtId];
      const cardWidth = 270;

      let srcY = srcPos.y + 70;
      let tgtY = tgtPos.y + 70;
      const srcColElem = srcNode.querySelector(`[data-col-name="${l.srcCol}"]`);
      const tgtColElem = tgtNode.querySelector(`[data-col-name="${l.tgtCol}"]`);
      if (srcColElem) srcY = srcPos.y + srcColElem.offsetTop + 12;
      if (tgtColElem) tgtY = tgtPos.y + tgtColElem.offsetTop + 12;

      let srcX = srcPos.x + cardWidth;
      let tgtX = tgtPos.x;
      if (tgtPos.x < srcPos.x) {
        srcX = srcPos.x;
        tgtX = tgtPos.x + cardWidth;
      }

      const dx = Math.max(50, Math.abs(tgtX - srcX) * 0.45);
      const c1x = srcX + (tgtX >= srcX ? dx : -dx);
      const c2x = tgtX + (tgtX >= srcX ? -dx : dx);

      path.setAttribute('d', `M ${srcX} ${srcY} C ${c1x} ${srcY}, ${c2x} ${tgtY}, ${tgtX} ${tgtY}`);
    });
  }

  function setupTableDrag(card, tableId) {
    card.addEventListener('pointerdown', (e) => {
      if (e.target.closest('button') || e.target.closest('.erd-card-body')) return;
      e.stopPropagation();
      card.setPointerCapture(e.pointerId);
      card.classList.add('dragging');

      const startX = e.clientX;
      const startY = e.clientY;
      const pos = erdPositions[tableId] || { x: card.offsetLeft, y: card.offsetTop };
      const origX = pos.x;
      const origY = pos.y;

      const onPointerMove = (ev) => {
        const dx = (ev.clientX - startX) / erdZoom;
        const dy = (ev.clientY - startY) / erdZoom;
        const newX = origX + dx;
        const newY = origY + dy;
        pos.x = newX;
        pos.y = newY;
        card.style.left = `${newX}px`;
        card.style.top = `${newY}px`;
        requestAnimationFrame(() => updateLinksForTable(tableId));
      };

      const onPointerUp = (ev) => {
        card.releasePointerCapture(ev.pointerId);
        card.classList.remove('dragging');
        card.removeEventListener('pointermove', onPointerMove);
        card.removeEventListener('pointerup', onPointerUp);
        erdPositions[tableId] = { x: pos.x, y: pos.y };
      };

      card.addEventListener('pointermove', onPointerMove);
      card.addEventListener('pointerup', onPointerUp);
    });
  }

  function highlightConnected(tableId) {
    if (!erdNodesLayer || !erdLinksGroup) return;
    const connectedTableIds = new Set([tableId]);

    const lines = erdLinksGroup.querySelectorAll('.erd-link-line');
    lines.forEach(l => {
      const src = l.getAttribute('data-src');
      const tgt = l.getAttribute('data-tgt');
      if (src === tableId || tgt === tableId) {
        l.classList.add('active');
        l.classList.remove('dimmed');
        connectedTableIds.add(src);
        connectedTableIds.add(tgt);
      } else {
        l.classList.add('dimmed');
        l.classList.remove('active');
      }
    });

    const cards = erdNodesLayer.querySelectorAll('.erd-table-card');
    cards.forEach(c => {
      const tId = c.dataset.tableId;
      if (connectedTableIds.has(tId)) {
        c.classList.add('highlighted');
        c.classList.remove('dimmed');
      } else {
        c.classList.add('dimmed');
        c.classList.remove('highlighted');
      }
    });
  }

  function highlightNode(tableId) {
    const card = $(`erd-node-${tableId.replace(/\./g, '__')}`);
    if (card) card.classList.add('highlighted');
  }

  function clearHighlight() {
    if (!erdNodesLayer || !erdLinksGroup) return;
    erdLinksGroup.querySelectorAll('.erd-link-line').forEach(l => {
      l.classList.remove('active', 'dimmed');
    });
    erdNodesLayer.querySelectorAll('.erd-table-card').forEach(c => {
      c.classList.remove('highlighted', 'dimmed');
    });
  }

  function fitERDToScreen() {
    if (!erdViewport || !erdNodesLayer) return;
    const cards = Array.from(erdNodesLayer.querySelectorAll('.erd-table-card'));
    if (cards.length === 0) return;

    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    cards.forEach(c => {
      const x = c.offsetLeft;
      const y = c.offsetTop;
      const w = c.offsetWidth || 270;
      const h = c.offsetHeight || 200;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x + w > maxX) maxX = x + w;
      if (y + h > maxY) maxY = y + h;
    });

    const padding = 60;
    const contentW = maxX - minX + padding * 2;
    const contentH = maxY - minY + padding * 2;
    const viewW = erdViewport.clientWidth || 1000;
    const viewH = erdViewport.clientHeight || 700;

    const scaleX = viewW / contentW;
    const scaleY = viewH / contentH;
    erdZoom = Math.min(1.2, Math.max(0.3, Math.min(scaleX, scaleY)));

    erdPanX = (viewW - (maxX - minX) * erdZoom) / 2 - minX * erdZoom;
    erdPanY = (viewH - (maxY - minY) * erdZoom) / 2 - minY * erdZoom;

    updateErdTransform();
  }

  if (erdViewport) {
    let isPanning = false;
    let panStartX = 0, panStartY = 0;

    erdViewport.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.erd-table-card') || e.target.closest('button') || e.target.closest('input')) return;
      isPanning = true;
      erdViewport.setPointerCapture(e.pointerId);
      erdViewport.classList.add('panning');
      panStartX = e.clientX - erdPanX;
      panStartY = e.clientY - erdPanY;

      const onPointerMove = (ev) => {
        if (!isPanning) return;
        erdPanX = ev.clientX - panStartX;
        erdPanY = ev.clientY - panStartY;
        updateErdTransform();
      };

      const onPointerUp = (ev) => {
        isPanning = false;
        erdViewport.releasePointerCapture(ev.pointerId);
        erdViewport.classList.remove('panning');
        erdViewport.removeEventListener('pointermove', onPointerMove);
        erdViewport.removeEventListener('pointerup', onPointerUp);
      };

      erdViewport.addEventListener('pointermove', onPointerMove);
      erdViewport.addEventListener('pointerup', onPointerUp);
    });

    erdViewport.addEventListener('wheel', (e) => {
      e.preventDefault();
      const rect = erdViewport.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;

      const oldZoom = erdZoom;
      const zoomFactor = e.deltaY < 0 ? 1.15 : 0.87;
      erdZoom = Math.max(0.2, Math.min(2.5, erdZoom * zoomFactor));

      erdPanX = mouseX - (mouseX - erdPanX) * (erdZoom / oldZoom);
      erdPanY = mouseY - (mouseY - erdPanY) * (erdZoom / oldZoom);
      updateErdTransform();
    }, { passive: false });
  }

  if (erdZoomIn) {
    erdZoomIn.addEventListener('click', () => {
      erdZoom = Math.min(2.5, erdZoom * 1.25);
      updateErdTransform();
    });
  }
  if (erdZoomOut) {
    erdZoomOut.addEventListener('click', () => {
      erdZoom = Math.max(0.2, erdZoom * 0.8);
      updateErdTransform();
    });
  }
  if (erdZoomFit) {
    erdZoomFit.addEventListener('click', fitERDToScreen);
  }
  if (erdAutoArrange) {
    erdAutoArrange.addEventListener('click', () => {
      buildAndRenderERD(true);
    });
  }
  if (erdSchemaSelect) {
    erdSchemaSelect.addEventListener('change', () => {
      buildAndRenderERD(true);
    });
  }
  if (erdSearchInput) {
    let erdSearchTimer = null;
    erdSearchInput.addEventListener('input', () => {
      clearTimeout(erdSearchTimer);
      erdSearchTimer = setTimeout(() => buildAndRenderERD(false), 200);
    });
  }

  // Initial load
  loadSchema();

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
