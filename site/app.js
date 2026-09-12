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
  var btnToggleAll = document.getElementById('toggle-all');
  var state = { path: null, mode: 'render', query: '' };
  var index = { byPath: {}, skills: [] };
  var searchTimer = null;

  if (!DATA || DATA.schemaVersion !== 1 || !Array.isArray(DATA.categories)) {
    elTree.innerHTML = '<div class="empty-tree">站点数据无效。<br>请运行 <code>python scripts/build-site.py</code>。</div>';
    return;
  }

  function normalized(value) {
    return String(value || '').toLocaleLowerCase();
  }

  DATA.categories.forEach(function (cat) {
    cat.skills.forEach(function (skill) {
      skill._search = normalized([
        cat.name, cat.title, skill.name, skill.description, (skill.tags || []).join(' ')
      ].join(' '));
      index.skills.push({ cat: cat, skill: skill });
      skill.files.forEach(function (file) {
        file.skill = skill;
        file.cat = cat;
        file._search = normalized([file.name, file.path, file.content].join(' '));
        index.byPath[file.path] = file;
      });
    });
  });

  var stats = DATA.stats;
  elStats.textContent = stats.categories + ' 个分类 · ' + stats.skills + ' 个 skill · ' +
    stats.files + ' 个文件' + (stats.templates ? ' · ' + stats.templates + ' 个模板' : '');

  if (window.marked && window.marked.setOptions) {
    window.marked.setOptions({ gfm: true, breaks: false });
  }

  function stripFrontmatter(text) {
    if (text.indexOf('---') !== 0) return text;
    var end = text.indexOf('\n---', 3);
    return end === -1 ? text : text.slice(end + 4).replace(/^\r?\n/, '');
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

  function githubFileUrl(path) {
    return REPO_URL + '/blob/master/' + path.split('/').map(encodeURIComponent).join('/');
  }

  function hashPath(path) {
    return '#' + encodeURIComponent(path);
  }

  function readHash() {
    if (!location.hash) return '';
    try {
      return decodeURIComponent(location.hash.slice(1));
    } catch (error) {
      return '';
    }
  }

  function copyText(value, button) {
    function done() {
      var previous = button.textContent;
      button.textContent = '已复制';
      button.classList.add('done');
      setTimeout(function () {
        button.textContent = previous;
        button.classList.remove('done');
      }, 1400);
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(value).then(done, function () {
        fallbackCopy(value, done);
      });
    } else {
      fallbackCopy(value, done);
    }
  }

  function fallbackCopy(value, done) {
    var textarea = document.createElement('textarea');
    textarea.value = value;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      done();
    } catch (error) {
      window.prompt('复制失败，请手动复制：', value);
    }
    textarea.remove();
  }

  function makeNode(className, label) {
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'node ' + className;
    button.setAttribute('aria-expanded', 'false');

    var caret = document.createElement('span');
    caret.className = 'caret';
    caret.textContent = '▶';
    caret.setAttribute('aria-hidden', 'true');

    var text = document.createElement('span');
    text.className = 'label';
    text.textContent = label;
    button.append(caret, text);
    return button;
  }

  function badge(text, className) {
    var element = document.createElement('span');
    element.className = 'badge' + (className ? ' ' + className : '');
    element.textContent = text;
    return element;
  }

  function categoryLabel(cat) {
    var icons = {
      development: '💻', devops: '⚙️', system: '🖥️', 'data-ai': '🤖',
      'office-docs': '📄', media: '🎨', research: '🔎', productivity: '✅',
      learning: '📚', finance: '📈', _templates: '📋'
    };
    var title = cat.title || cat.name;
    if (cat.meta) title += '（仅供参考）';
    return (icons[cat.name] || '📁') + ' ' + title + '（' + cat.skills.length + '）';
  }

  function setExpanded(button, children, expanded) {
    children.hidden = !expanded;
    button.setAttribute('aria-expanded', String(expanded));
    button.querySelector('.caret').classList.toggle('open', expanded);
  }

  function updateTreeToggle() {
    var groups = elTree.querySelectorAll('.children');
    var allOpen = groups.length > 0 && Array.prototype.every.call(groups, function (item) {
      return !item.hidden;
    });
    btnToggleAll.textContent = allOpen ? '全部折叠' : '全部展开';
    btnToggleAll.setAttribute('aria-expanded', String(allOpen));
  }

  function setAllTreeNodes(expanded) {
    elTree.querySelectorAll('.node[aria-expanded]').forEach(function (button) {
      var childrenId = button.getAttribute('aria-controls');
      var children = childrenId && document.getElementById(childrenId);
      if (children) setExpanded(button, children, expanded);
    });
    updateTreeToggle();
  }

  function renderTree() {
    var query = normalized(state.query.trim());
    elTree.textContent = '';
    var shown = 0;
    var nodeSequence = 0;

    DATA.categories.forEach(function (cat) {
      var visibleSkills = [];
      cat.skills.forEach(function (skill) {
        var skillMatch = !query || skill._search.indexOf(query) !== -1;
        var files = skill.files;
        if (!skillMatch && query) {
          files = skill.files.filter(function (file) {
            return file._search.indexOf(query) !== -1;
          });
        }
        if (skillMatch || files.length) visibleSkills.push({ skill: skill, files: files });
      });
      if (!visibleSkills.length) return;
      shown += visibleSkills.length;

      var group = document.createElement('div');
      group.className = 'tree-group';
      var catButton = makeNode('node-cat', categoryLabel(cat));
      var catChildren = document.createElement('div');
      catChildren.className = 'children';
      catChildren.id = 'tree-group-' + (++nodeSequence);
      catButton.setAttribute('aria-controls', catChildren.id);
      setExpanded(catButton, catChildren, true);
      catButton.addEventListener('click', function () {
        setExpanded(catButton, catChildren, catChildren.hidden);
        updateTreeToggle();
      });

      visibleSkills.forEach(function (item) {
        var skill = item.skill;
        var skillButton = makeNode('node-skill', '🧩 ' + skill.name);
        if (skill.platform && skill.platform !== 'all') {
          skillButton.appendChild(badge(skill.platform === 'windows' ? 'win' : skill.platform,
            skill.platform === 'windows' ? 'win' : ''));
        }

        var fileWrap = document.createElement('div');
        fileWrap.className = 'children';
        fileWrap.id = 'tree-group-' + (++nodeSequence);
        skillButton.setAttribute('aria-controls', fileWrap.id);
        var initiallyOpen = Boolean(query || (state.path && state.path.indexOf(skill.dir + '/') === 0));
        setExpanded(skillButton, fileWrap, initiallyOpen);

        item.files.forEach(function (file) {
          var fileButton = makeNode('node-file', file.name);
          fileButton.removeAttribute('aria-expanded');
          fileButton.title = file.path;
          if (file.path === state.path) {
            fileButton.classList.add('active');
            fileButton.setAttribute('aria-current', 'page');
          }
          fileButton.addEventListener('click', function (event) {
            event.stopPropagation();
            select(file.path);
          });
          fileWrap.appendChild(fileButton);
        });

        skillButton.addEventListener('click', function () {
          setExpanded(skillButton, fileWrap, fileWrap.hidden);
          updateTreeToggle();
          var main = skill.files.find(function (file) { return file.name === 'SKILL.md'; }) || skill.files[0];
          if (main) select(main.path);
        });
        catChildren.append(skillButton, fileWrap);
      });

      group.append(catButton, catChildren);
      elTree.appendChild(group);
    });

    if (!shown) {
      var empty = document.createElement('div');
      empty.className = 'empty-tree';
      empty.textContent = '没有匹配 \u201c' + state.query + '\u201d 的 skill';
      elTree.appendChild(empty);
    }
    updateTreeToggle();
  }

  function renderMetadata(file) {
    elMeta.textContent = '';
    var parts = [humanSize(file.size), file.lang];
    if (file.skill.tags && file.skill.tags.length) {
      parts.push('标签：' + file.skill.tags.join('、'));
    }
    elMeta.appendChild(document.createTextNode(parts.join(' · ') + ' · '));
    var link = document.createElement('a');
    link.href = githubFileUrl(file.path);
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    link.textContent = '在 GitHub 查看';
    elMeta.appendChild(link);
  }

  function highlightRaw(file) {
    elRawCode.removeAttribute('data-highlighted');
    elRawCode.className = '';
    elRawCode.textContent = file.content;
    if (!window.hljs || file.binary) return;
    try {
      var language = window.hljs.getLanguage(file.lang) ? file.lang : 'plaintext';
      var result = window.hljs.highlight(file.content, { language: language });
      elRawCode.innerHTML = result.value;
      elRawCode.className = 'hljs language-' + language;
    } catch (error) {
      elRawCode.textContent = file.content;
    }
  }

  function renderMarkdown(file) {
    if (!window.marked || !window.DOMPurify) {
      elRendered.textContent = stripFrontmatter(file.content);
      return;
    }
    var html = window.marked.parse(stripFrontmatter(file.content));
    elRendered.innerHTML = window.DOMPurify.sanitize(html, {
      USE_PROFILES: { html: true },
      FORBID_TAGS: ['style'],
      FORBID_ATTR: ['style']
    });
    if (window.hljs) {
      elRendered.querySelectorAll('pre code').forEach(function (block) {
        try { window.hljs.highlightElement(block); } catch (error) { /* unsupported language */ }
      });
    }
  }

  function select(path) {
    var file = index.byPath[path];
    if (!file) return;
    state.path = path;
    if (!isMarkdown(file)) state.mode = 'raw';

    elPlaceholder.hidden = true;
    elViewer.hidden = false;
    elCrumb.textContent = path;
    elCrumb.title = path;
    renderMetadata(file);

    if (file.binary) {
      elRawNotice.hidden = false;
      elRawNotice.textContent = '这是一个二进制文件，无法在页面内显示。请从 GitHub 下载。';
    } else if (file.truncated) {
      elRawNotice.hidden = false;
      elRawNotice.textContent = '文件超过 512 KB，此处只显示前 512 KB，复制内容也会被截断。';
    } else {
      elRawNotice.hidden = true;
    }

    highlightRaw(file);
    if (isMarkdown(file)) {
      renderMarkdown(file);
      btnRender.disabled = false;
    } else {
      elRendered.textContent = '非 Markdown 文件，请切换到“源码”查看。';
      btnRender.disabled = true;
    }

    setMode(file.binary || btnRender.disabled ? 'raw' : state.mode);
    renderTree();
    history.replaceState(null, '', hashPath(path));
  }

  function setMode(mode) {
    state.mode = mode;
    var raw = mode === 'raw';
    elRaw.hidden = !raw;
    elRendered.hidden = raw;
    btnRaw.classList.toggle('on', raw);
    btnRender.classList.toggle('on', !raw);
    btnRaw.setAttribute('aria-pressed', String(raw));
    btnRender.setAttribute('aria-pressed', String(!raw));
    document.getElementById('content').scrollTop = 0;
  }

  btnRender.addEventListener('click', function () { setMode('render'); });
  btnRaw.addEventListener('click', function () { setMode('raw'); });
  btnCopy.addEventListener('click', function () {
    var file = index.byPath[state.path];
    if (file) copyText(file.content, btnCopy);
  });
  btnToggleAll.addEventListener('click', function () {
    setAllTreeNodes(btnToggleAll.getAttribute('aria-expanded') !== 'true');
  });

  elSearch.addEventListener('input', function () {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(function () {
      state.query = elSearch.value;
      renderTree();
    }, 180);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === '/' && document.activeElement !== elSearch) {
      event.preventDefault();
      elSearch.focus();
      elSearch.select();
    } else if (event.key === 'Escape' && document.activeElement === elSearch) {
      clearTimeout(searchTimer);
      elSearch.value = '';
      state.query = '';
      renderTree();
      elSearch.blur();
    }
  });

  window.addEventListener('hashchange', function () {
    var path = readHash();
    if (path && path !== state.path && index.byPath[path]) select(path);
  });

  renderTree();
  var initial = readHash();
  if (initial && index.byPath[initial]) {
    select(initial);
  } else {
    var first = null;
    DATA.categories.some(function (cat) {
      return cat.skills.some(function (skill) {
        first = skill.files.find(function (file) { return file.name === 'SKILL.md'; });
        return Boolean(first);
      });
    });
    if (first) select(first.path);
  }
})();
