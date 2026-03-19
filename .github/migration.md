# Publishing Orchestra — Migration Guide

How to lift the publishing orchestra from `caseload-forecast-demo` into another repository that does not have it yet.

---

## What You Are Migrating

The publishing orchestra is a **two-agent system** (Interviewer + Writer) that turns an analytics repository into a static Quarto website. It lives entirely in `.github/` and works without touching any of the repo's existing code.

**Files to copy** (7 files across `.github/`):

```
.github/
├── publishing-orchestra-3.md                   ← Design doc (read-only reference)
├── agents/
│   ├── publishing-interviewer.agent.md          ← Interviewer agent
│   └── publishing-writer.agent.md               ← Writer agent
├── instructions/
│   └── publishing-rules.instructions.md         ← Writer rules (applyTo: _frontend-*/**)
├── templates/
│   └── publishing-contract-template.md          ← Contract schema
├── copilot/
│   └── publishing-orchestra-SKILL.md            ← Skill for discoverability
└── prompts/
    └── publishing-new.prompt.md                 ← Bootstrap new frontend
```

---

## Prerequisites in the Target Repo

Before migrating, verify:

- [ ] [Quarto](https://quarto.org/) is installed (`quarto --version`)
- [ ] R is available (`Rscript --version`) — needed for post-render hooks
- [ ] The target repo has at least one EDA report beyond EDA-1 (e.g., `analysis/eda-2/`)
- [ ] The target repo has at least one non-exploratory report (e.g., `analysis/report-1/`)
- [ ] VS Code with GitHub Copilot (agent mode) is available

---

## Migration Steps

### Step 1 — Copy the framework files

Copy all 7 files listed above from `caseload-forecast-demo/.github/` into the target repo's `.github/`. Preserve the directory structure exactly.

```bash
# From a workspace containing both repos, e.g.:
cp -r caseload-forecast-demo/.github/agents target-repo/.github/
cp -r caseload-forecast-demo/.github/instructions target-repo/.github/
cp -r caseload-forecast-demo/.github/templates target-repo/.github/
cp -r caseload-forecast-demo/.github/copilot target-repo/.github/
cp -r caseload-forecast-demo/.github/prompts target-repo/.github/
cp caseload-forecast-demo/.github/publishing-orchestra-3.md target-repo/.github/
```

Or on Windows (PowerShell):

```powershell
$src = "path\to\caseload-forecast-demo\.github"
$dst = "path\to\target-repo\.github"
Copy-Item "$src\publishing-orchestra-3.md" $dst
Copy-Item "$src\agents" $dst -Recurse
Copy-Item "$src\instructions" $dst -Recurse
Copy-Item "$src\templates" $dst -Recurse
Copy-Item "$src\copilot" $dst -Recurse
Copy-Item "$src\prompts" $dst -Recurse
```

### Step 2 — Verify VS Code picks up the agents

Open the target repo in VS Code. In the Copilot chat panel, type `@` and confirm that **Publishing Interviewer** and **Publishing Writer** appear in the agent list.

If they do not appear:

- Check that `.github/agents/publishing-interviewer.agent.md` and `publishing-writer.agent.md` exist
- Reload VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window")

### Step 3 — Adapt `copilot-instructions.md` (if target repo has one)

If the target repo has a `.github/copilot-instructions.md`, add a reference to the publishing orchestra so the default agent knows it exists:

```markdown
## Publishing Orchestra

This repo includes a two-agent publishing system for generating static Quarto websites from analytics content.
- **Interviewer** (`@publishing-interviewer`): Plans the site, produces the contract.
- **Writer** (`@publishing-writer`): Assembles `edited_content/`, renders `_site/`.
- Design doc: `.github/publishing-orchestra-3.md`
- Migration guide: `.github/migration.md`
```

### Step 4 — Adapt the `applyTo` pattern (if needed)

The `publishing-rules.instructions.md` file has a frontmatter directive:

```yaml
applyTo: "_frontend-*/**"
```

This tells VS Code to apply the rules only to files in `_frontend-N/` folders. If the target repo uses a different naming convention for frontend workspaces (e.g., `_site-N/`), update the `applyTo` pattern to match.

### Step 5 — Create the first frontend

Follow the standard workflow:

1. Create `analysis/frontend-N/initial.prompt.md` — fill in your intent.
2. Invoke `@publishing-interviewer` — it will scan the repo, interview you, and produce `_frontend-N/publishing-contract.prompt.md`.
3. Review and confirm the contract.
4. Invoke `@publishing-writer` — it will assemble `edited_content/`, generate `_quarto.yml`, and render `_site/`.

Or use the bootstrap prompt if available:

```
@publishing-interviewer #file:.github/prompts/publishing-new.prompt.md
```

---

## What Does NOT Transfer Automatically

- **`ai/` directory**: The persona system, dynamic context builder, and project-specific AI config are repo-specific. Do not copy them unless the target repo has the same structure.
- **`analysis/` content**: EDA and report files are repo-specific. The orchestra reads them from the target repo.
- **`data-public/` manifests**: These are produced by the target repo's own pipeline.
- **`llms.txt`**: Repo-specific LLM context file, if present.

---

## Minimal Viable Target Repo Structure

For the orchestra to function, the target repo needs:

```
target-repo/
├── .github/
│   ├── publishing-orchestra-3.md
│   ├── agents/
│   │   ├── publishing-interviewer.agent.md
│   │   └── publishing-writer.agent.md
│   ├── instructions/
│   │   └── publishing-rules.instructions.md
│   ├── templates/
│   │   └── publishing-contract-template.md
│   ├── copilot/
│   │   └── publishing-orchestra-SKILL.md
│   └── prompts/
│       └── publishing-new.prompt.md
├── analysis/
│   ├── eda-2/          ← Must exist (EDA beyond EDA-1)
│   │   └── eda-2.html
│   └── report-1/       ← Must exist (non-exploratory report)
│       └── report-1.html
└── README.md           ← Used by Interviewer for project context
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Agents not visible in VS Code | Reload window; verify `.agent.md` files are in `.github/agents/` |
| `publishing-rules` not applying | Check `applyTo` frontmatter matches `_frontend-*/**` pattern |
| Interviewer refuses to proceed | Verify `analysis/eda-2/` and `analysis/report-1/` exist with rendered HTML |
| Post-render hook fails | Verify R is on PATH; check paths in `scripts/copy-analysis-html.R` match your repo structure |
| Mermaid diagram not rendering | Ensure `_quarto.yml` includes `format: html: mermaid: theme: neutral` |

---

## Version Reference

This migration guide is written against **Publishing Orchestra v3** (`publishing-orchestra-3.md`, March 2026).
If you encounter a newer design doc in `caseload-forecast-demo/.github/`, check whether a newer migration guide supersedes this one.
