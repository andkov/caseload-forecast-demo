# questions.prompt.md Template

This template defines the schema for `questions.prompt.md` — the file the Publishing Publisher writes when it encounters a blocker it cannot resolve deterministically. The Orchestrator reads this file and routes each question to the human for resolution.

---

## Schema

```markdown
# Publisher Questions

Questions generated during the publishing build. Each question blocks further progress until resolved.

## Q1

- **Issue**: [Brief description of the problem]
- **Step**: [Which workflow step is blocked: scaffold / build-config / place-content / render / reconcile]
- **File(s)**: [Affected file path(s)]
- **Options**:
  1. [First possible resolution]
  2. [Second possible resolution]
  3. [Other / custom resolution]
- **Required action**: [What the human needs to decide or provide]
- **Status**: open

## Q2

- **Issue**: ...
- **Step**: ...
- **File(s)**: ...
- **Options**: ...
- **Required action**: ...
- **Status**: open
```

---

## Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| Issue | Yes | One-line description of the problem |
| Step | Yes | Publisher workflow step where the block occurred |
| File(s) | Yes | Path(s) to the affected file(s) |
| Options | Yes | Numbered list of possible resolutions (at least 2) |
| Required action | Yes | What the human must decide or supply |
| Status | Yes | `open` when written; Orchestrator sets to `resolved` after handling |

---

## Lifecycle

1. **Publisher writes**: Creates `questions.prompt.md` with one or more `open` questions, then stops execution.
2. **Orchestrator reads**: Detects the file, presents each question to the human.
3. **Human decides**: Provides answers for each question.
4. **Orchestrator updates**: Applies the human's decisions to the relevant contract files (`editor.prompt.md`, `publisher.prompt.md`, or `content/` files).
5. **Orchestrator deletes**: Removes `questions.prompt.md` after all questions are resolved.
6. **Orchestrator re-invokes**: Runs the Publisher again.

---

## Constraints

- The Publisher must **stop immediately** after writing this file — no partial builds, no workarounds.
- Each question must present **at least two options** so the human has a clear choice.
- The Orchestrator must **delete** this file before re-invoking the Publisher to prevent stale questions from persisting.
