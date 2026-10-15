import Foundation

/// CSS for the rendered Markdown document. Adapts to light/dark mode via
/// `prefers-color-scheme`.
public enum MarkdownCSS {

    public static let document: String = """
    :root {
      color-scheme: light dark;
      --fg: #1f2328;
      --fg-muted: #59636e;
      --bg: #ffffff;
      --border: #d1d9e0;
      --code-bg: #f6f8fa;
      --quote-bar: #d1d9e0;
      --link: #0969da;
      --table-stripe: #f6f8fa;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --fg: #e6edf3;
        --fg-muted: #9198a1;
        --bg: #0d1117;
        --border: #3d444d;
        --code-bg: #151b23;
        --quote-bar: #3d444d;
        --link: #4493f8;
        --table-stripe: #161b22;
      }
    }

    html, body {
      margin: 0;
      padding: 0;
      background: var(--bg);
      color: var(--fg);
      min-height: 100vh;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
      font-size: 15px;
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
    }

    .markdown-body {
      max-width: 860px;
      margin: 0 auto;
      padding: 32px 40px 120px;
      word-wrap: break-word;
    }

    .markdown-body > *:first-child { margin-top: 0; }

    h1, h2, h3, h4, h5, h6 {
      font-weight: 600;
      line-height: 1.3;
      margin: 1.6em 0 0.6em;
    }
    h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: .875em; }
    h6 { font-size: .85em; color: var(--fg-muted); }

    p { margin: 0 0 1em; }

    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }

    code {
      font-family: ui-monospace, "SF Mono", Menlo, Monaco, "Cascadia Code", monospace;
      font-size: .875em;
      background: var(--code-bg);
      padding: .2em .4em;
      border-radius: 6px;
    }

    pre {
      background: var(--code-bg);
      padding: 16px;
      border-radius: 6px;
      overflow: auto;
      line-height: 1.45;
      margin: 0 0 1em;
    }
    pre code {
      background: transparent;
      padding: 0;
      font-size: .85em;
      white-space: pre;
    }

    blockquote {
      margin: 0 0 1em;
      padding: 0 1em;
      color: var(--fg-muted);
      border-left: .25em solid var(--quote-bar);
    }

    ul, ol { margin: 0 0 1em; padding-left: 2em; }
    li + li { margin-top: .25em; }
    li > ul, li > ol { margin: .25em 0; }
    li input[type="checkbox"] { margin-right: .4em; }
    ul:has(> li > input[type="checkbox"]) { list-style: none; padding-left: 1.4em; }

    hr {
      border: 0;
      border-top: 1px solid var(--border);
      margin: 1.6em 0;
    }

    img { max-width: 100%; height: auto; }

    table {
      border-collapse: collapse;
      margin: 0 0 1em;
      display: block;
      max-width: 100%;
      overflow: auto;
    }
    th, td {
      border: 1px solid var(--border);
      padding: 6px 13px;
    }
    th { font-weight: 600; background: var(--code-bg); }
    tbody tr:nth-child(2n) { background: var(--table-stripe); }

    .empty-state {
      color: var(--fg-muted);
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      font-size: 16px;
    }
    """
        + "\n"

    /// A small placeholder page shown when no document is selected.
    public static let emptyPage: String = """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><style>\(document)</style></head>
    <body><div class="empty-state">No markdown file open</div></body>
    </html>
    """

    /// Wraps a rendered HTML fragment in a full HTML document with styling.
    public static func page(for html: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(document)</style>
        </head>
        <body>
        <article class="markdown-body">
        \(html)
        </article>
        </body>
        </html>
        """
    }
}
