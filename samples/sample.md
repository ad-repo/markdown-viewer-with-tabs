# Markdown Viewer — Sample

A quick document exercising **all** the supported Markdown / GitHub Flavored
Markdown features. Visit https://example.com or email us for details.

## Text formatting

*Italic*, **bold**, ***bold italic***, ~~strikethrough~~, `inline code`,
and a [link with title](https://example.com "Example").

## Lists

- First item
- Second item
  - Nested item
  - Another nested item
- Third item

1. Ordered one
2. Ordered two
3. Ordered three

### Task list

- [x] Support tables
- [x] Support task lists
- [ ] Take over the world

## Blockquote

> The best way out is always through.
> — Robert Frost

## Code

Inline `let x = 42`, and a fenced block:

```swift
struct Greeting {
    let name: String
    func hello() -> String { "Hello, \(name)!" }
}
```

```python
def greet(name):
    return f"Hello, {name}!"
```

## Table

| Feature      | Supported | Notes               |
| :----------- | :-------: | ------------------: |
| Headings     |    Yes    | levels 1–6          |
| Tables       |    Yes    | with alignment      |
| Task lists   |    Yes    | checkboxes          |
| Raw HTML     |    Yes    | inline and blocks   |

## Raw HTML

<div style="padding:8px;border:1px dashed gray;border-radius:6px">
  This is <strong>raw HTML</strong> passed through.
</div>

## Image (remote)

![Swift logo](https://www.swift.org/assets/images/swift.svg)

## Thematic break

---

That's everything. 🎉
