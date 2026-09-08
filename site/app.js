(function () {
  'use strict';

  var REPO_URL = 'https://github.com/yeyongzhi/aurora-skills';
  var DATA = window.__SKILLS__;

  var elTree = document.getElementById('tree');
  var elStats = document.getElementById('stats');
  var elSearch = document.getElementById('search');
  var elPlaceholder = document.getElementById('placeholder');
  var elViewer = document.getElementById('viewer');
  var elCrumb = document.getElementById('crumb');
  var elMeta = document.getElementById('file-meta');
  var elRendered = document.getElementById('rendered');
  var elRaw = document.getElementById('raw');
  var elRawCode = document.getElementById('raw-code');
  var elRawNotice = document.getElementById('raw-notice');
  var btnRender = document.getElementById('view-render');
  var btnRaw = document.getElementById('view-raw');
  var btnCopy = document.getElementById('copy');
  var btnCopyPath = document.getElementById('copy-path');

  var state = { path: null, mode: 'render', query: '' };
  var index = { byPath: {}, skills: [] };

  /* ---------- 初始化 ---------- */

  if (!DATA || !DATA.categories) {
    elTree.innerHTML = '<div class="empty-tree">未加载到数据。<br>请先运行 <code>python scripts/build-site.py</code> 生成 <code>site/data/skills.js</code>。</div>';
    return;
  }

  DATA.categories.forEach(function (cat) {
    cat.skills.forEach(function (skill) {
      index.skills.push({ cat: cat, skill: skill });
      skill.files.forEach(function (file) {
        file.skill = skill;
        file.cat = cat;
        index.byPath[file.path] = file;
      });
    });
  });

  var s = DATA.stats;
  elStats.textContent = s.categories + ' 个分类 · ' + s.skills + ' 个 skill · ' + s.files + ' 个文件';

  if (typeof marked !== 'undefined' && marked.setOptions) {
    marked.setOptions({ gfm: true, breaks: false });
  }

  /* ---------- 工具函数 ---------- */

  function stripFrontmatter(text) {
    if (text.indexOf('---') !== 0) return text;
    var end = text.indexOf('\n---', 3);
    if (end === -1) return text;
    return text.slice(end + 4).replace(/^\r?\n/, '');
  }

  function isMarkdown(file) {
    return file.lang === 'markdown';
  }

  function humanSize(bytes) {
    if (!bytes) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }

  function copyText(text, btn) {
    function done() {
      if (!btn) return;
      var old = btn.textContent;
      btn.textContent = '已复制';
      btn.classList.add('done');
      setTimeout(function () {
        btn.textContent = old;
        btn.classList.remove('done');
      }, 1400);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {
        fallbackCopy(text, done);
      });
      return;
    }
    fallbackCopy(text, done);
  }

  function fallbackCopy(text, done) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand('copy');
      done();
    } catch (e) {
      window.prompt('复制失败，请手动复制：', text);
    }
    document.body.removeChild(ta);
  }

  /* ---------- 目录树 ---------- */

  function makeNode(cls, label, extra) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'node ' + cls;
    var caret = document.createElement('span');
    caret.className = 'caret';
    caret.textContent = '▶';
    btn.appendChild(caret);
    var span = document.createElement('span');
    span.className = 'label';
    span.textContent = label;
    btn.appendChild(span);
    if (extra) btn.appendChild(extra);
    return btn;
  }

  function badge(text, cls) {
    var b = document.createElement('span');
    b.className = 'badge' + (cls ? ' ' + cls : '');
    b.textContent = text;
    return b;
  }

  function countSpan(n) {
    var c = document.createElement('span');
    c.className = 'count';
    c.textContent = n;
    return c;
  }

  function matches(text, q) {
    return String(text || '').toLowerCase().indexOf(q) !== -1;
  }

  function renderTree() {
    var q = state.query.trim().toLowerCase();
    elTree.innerHTML = '';
    var shown = 0;

    DATA.categories.forEach(function (cat) {
      var catHit = q && (matches(cat.name, q) || matches(cat.title, q));
      var visibleSkills = [];

      cat.skills.forEach(function (skill) {
        var skillHit = q && (
          matches(skill.name, q) ||
          matches(skill.description, q) ||
          (skill.tags || []).some(function (t) { return matches(t, q); })
        );
        if (q && !catHit && !skillHit) {
          var hitFiles = skill.files.filter(function (f) {
            return !f.binary && matches(f.content, q);
          });
          if (hitFiles.length) {
            visibleSkills.push({ skill: skill, files: hitFiles, partial: true });
          }
          return;
        }
        visibleSkills.push({ skill: skill, files: skill.files, partial: false });
      });

      if (q && !catHit && visibleSkills.length === 0) return;
      shown += visibleSkills.length;

      var group = document.createElement('div');
      group.className = 'tree-group';

      var catBtn = makeNode('node-cat', cat.title || cat.name);
      catBtn.title = cat.name + '/';
      catBtn.appendChild(countSpan(cat.skills.length));
      var catChildren = document.createElement('div');
      catChildren.className = 'children';

      catBtn.querySelector('.caret').classList.add('open');

      catBtn.addEventListener('click', function () {
        var open = catChildren.hasAttribute('hidden');
        if (open) catChildren.removeAttribute('hidden');
        else catChildren.setAttribute('hidden', '');
        catBtn.querySelector('.caret').classList.toggle('open', open);
      });

      visibleSkills.forEach(function (item) {
        var skill = item.skill;
        var skillBtn = makeNode('node-skill', skill.name);
        if (skill.platform && skill.platform !== 'all') {
          skillBtn.appendChild(badge(skill.platform === 'windows' ? 'win' : skill.platform,
            skill.platform === 'windows' ? 'win' : null));
        }
        var fileWrap = document.createElement('div');
        fileWrap.className = 'children';
        var skillOpen = !!q || state.path && state.path.indexOf(skill.dir + '/') === 0;
        fileWrap.setAttribute('hidden', '');

        item.files.forEach(function (file) {
          var fileBtn = makeNode('node-file', file.name);
          fileBtn.title = file.path;
          if (file.path === state.path) fileBtn.classList.add('active');
          fileBtn.addEventListener('click', function (e) {
            e.stopPropagation();
            select(file.path);
          });
          fileWrap.appendChild(fileBtn);
        });

        skillBtn.addEventListener('click', function () {
          var open = fileWrap.hasAttribute('hidden');
          if (open) fileWrap.removeAttribute('hidden');
          else fileWrap.setAttribute('hidden', '');
          skillBtn.querySelector('.caret').classList.toggle('open', open);
          var main = skill.files.filter(function (f) { return f.name === 'SKILL.md'; })[0] || skill.files[0];
          if (main) select(main.path);
        });

        if (skillOpen) {
          fileWrap.removeAttribute('hidden');
          skillBtn.querySelector('.caret').classList.add('open');
        }

        catChildren.appendChild(skillBtn);
        catChildren.appendChild(fileWrap);
      });

      group.appendChild(catBtn);
      group.appendChild(catChildren);
      elTree.appendChild(group);
    });

    if (shown === 0) {
      var empty = document.createElement('div');
      empty.className = 'empty-tree';
      empty.textContent = '没有匹配 “' + state.query + '” 的 skill';
      elTree.appendChild(empty);
    }
  }

  /* ---------- 内容区 ---------- */

  function select(path) {
    var file = index.byPath[path];
    if (!file) return;
    state.path = path;
    if (!isMarkdown(file)) state.mode = 'raw';

    elPlaceholder.hidden = true;
    elViewer.hidden = false;

    elCrumb.textContent = path;
    elCrumb.title = path;

    var meta = [];
    meta.push(humanSize(file.size));
    meta.push(file.lang);
    if (file.skill.tags && file.skill.tags.length) {
      meta.push('标签：' + file.skill.tags.join('、'));
    }
    var link = '<a href="' + REPO_URL + '/blob/master/' + file.path +
      '" target="_blank" rel="noopener">在 GitHub 查看</a>';
    elMeta.innerHTML = meta.join(' · ') + ' · ' + link;

    if (file.binary) {
      elRawNotice.hidden = false;
      elRawNotice.textContent = '这是一个二进制文件，无法在页面内显示。请从 GitHub 下载。';
      elRawCode.textContent = '';
    } else if (file.truncated) {
      elRawNotice.hidden = false;
      elRawNotice.textContent = '文件超过 512 KB，此处只显示前半部分，复制的内容同样被截断。';
      elRawCode.textContent = file.content;
    } else {
      elRawNotice.hidden = true;
      elRawCode.textContent = file.content;
    }

    if (typeof window.hljs !== 'undefined') {
      try { window.hljs.highlightElement(elRawCode); } catch (e) { /* 忽略语言不支持 */ }
    }

    if (isMarkdown(file) && typeof marked !== 'undefined') {
      elRendered.innerHTML = marked.parse(stripFrontmatter(file.content));
      btnRender.disabled = false;
    } else if (isMarkdown(file)) {
      elRendered.textContent = stripFrontmatter(file.content);
      btnRender.disabled = false;
    } else {
      elRendered.innerHTML = '<p>非 Markdown 文件，请切换到「原文」查看。</p>';
      btnRender.disabled = true;
    }

    setMode(file.binary ? 'raw' : (btnRender.disabled ? 'raw' : state.mode));
    renderTree();
    history.replaceState(null, '', '#' + path);
  }

  function setMode(mode) {
    state.mode = mode;
    var raw = mode === 'raw';
    elRaw.hidden = !raw;
    elRendered.hidden = raw;
    btnRaw.classList.toggle('on', raw);
    btnRender.classList.toggle('on', !raw);
    document.getElementById('content').scrollTop = 0;
  }

  /* ---------- 事件 ---------- */

  btnRender.addEventListener('click', function () { setMode('render'); });
  btnRaw.addEventListener('click', function () { setMode('raw'); });

  btnCopy.addEventListener('click', function () {
    var file = index.byPath[state.path];
    if (file) copyText(file.content, btnCopy);
  });

  btnCopyPath.addEventListener('click', function () {
    if (state.path) copyText(state.path, btnCopyPath);
  });

  elSearch.addEventListener('input', function () {
    state.query = elSearch.value;
    renderTree();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && document.activeElement !== elSearch) {
      e.preventDefault();
      elSearch.focus();
      elSearch.select();
    } else if (e.key === 'Escape' && document.activeElement === elSearch) {
      elSearch.value = '';
      state.query = '';
      renderTree();
      elSearch.blur();
    }
  });

  window.addEventListener('hashchange', function () {
    var p = location.hash.slice(1);
    if (p && p !== state.path && index.byPath[p]) select(p);
  });

  /* ---------- 启动 ---------- */

  renderTree();

  var initial = location.hash.slice(1);
  if (initial && index.byPath[initial]) {
    select(initial);
  } else {
    var first = null;
    DATA.categories.some(function (cat) {
      return cat.skills.some(function (skill) {
        var main = skill.files.filter(function (f) { return f.name === 'SKILL.md'; })[0];
        if (main) { first = main.path; return true; }
        return false;
      });
    });
    if (first) select(first);
  }
})();
