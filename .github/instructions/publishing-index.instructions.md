---
description: "Rules for generating the website index/landing page from the project README. Covers content adaptation, link rewriting, and site-map alignment."
applyTo: "_frontend-*/**"
---

# Publishing Index Instructions

Rules for creating the website landing page (index) from the repository's root `README.md`.

---

## Source

The root `README.md` is the default source for the website index page unless `editor.prompt.md` specifies a different file.

## Transformation Rules

1. **Copy, don't edit**: Build the index from a transformed copy of `README.md`. Never modify the original.
2. **Adapt for website audience**: The repository README often contains developer-focused content (setup instructions, dependency management, contribution guidelines) that may not be relevant to website visitors. Adapt the content:
   - Retain: project purpose, overview, key features, links to documentation.
   - Remove or minimize: Git clone instructions, `renv` setup, environment configuration, CI/CD details.
   - Reword section headings if needed to fit the website navigation context.
3. **Rewrite internal links**: Update links that point to repository files so they resolve within the website. For example:
   - `./guides/getting-started.md` → `guides/getting-started.html` (if that page exists in the site).
   - Links to files not included in the website should be removed or replaced with brief descriptions.
4. **Align with site map**: If `editor.prompt.md` or `printer.prompt.md` defines navigation sections, ensure the index page's content and links are consistent with that structure.
5. **Apply user notes**: If `editor.prompt.md` contains notes about the index page, apply them during transformation.

## Output

- Place the transformed index as `content/index.qmd` (or `content/index.md`).
- Ensure it has proper frontmatter:

```yaml
---
title: "<Website Name>"
---
```

## Constraints

- Preserve the core meaning and factual content of the README.
- Do not add content that does not exist in the README or `editor.prompt.md`.
- Do not expose sensitive paths (`data-private/`, credentials, internal URLs).
- Do not include raw build/debug commands as visible page content.
