# Vendored browser dependencies

These files keep the static site usable from `file://` without network access.

| Library | Version | Source |
| --- | --- | --- |
| Marked | 12.0.2 | https://www.npmjs.com/package/marked/v/12.0.2 |
| DOMPurify | 3.1.6 | https://www.npmjs.com/package/dompurify/v/3.1.6 |
| Highlight.js | 11.9.0 | https://www.npmjs.com/package/highlight.js/v/11.9.0 |

Corresponding license files are stored in this directory. Upgrade a library by replacing
its pinned files and license, updating `site/index.html`, then running the repository tests
and the browser smoke checks.
