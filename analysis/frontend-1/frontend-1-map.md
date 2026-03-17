# Frontend-1 Site Map

Visual overview of the `frontend-1` website: program context, site structure, and the Publishing Orchestra pipeline that builds it.

---

## Program Context

The Alberta Income Support Caseload Forecast sits within the broader Alberta Learning and Social Services ministry hierarchy.

```mermaid
flowchart TD
    GOA["Government of Alberta"]
    ALSS["Alberta Learning\n& Social Services"]
    IS["Income Support Program"]
    CF["Caseload Forecast\nPipeline"]
    SITE["_frontend-1\nProject Website"]

    GOA --> ALSS
    ALSS --> IS
    IS --> CF
    CF --> SITE
```

---

## Site Structure

Pages and source files for the `frontend-1` website, organized by navbar section.

```mermaid
flowchart LR
    classDef section fill:#e8eaf6,stroke:#5c6bc0,font-weight:bold
    classDef page   fill:#f5f5f5,stroke:#9e9e9e
    classDef tbd    fill:#fff9c4,stroke:#f9a825,font-style:italic

    SITE(["Alberta IS Forecast\nWebsite"])

    SITE --> IDX["Index"]:::page
    SITE --> PRJ["Project"]:::section
    SITE --> PIP["Pipeline"]:::section
    SITE --> ANA["Analysis"]:::section
    SITE --> STO["Stories"]:::section
    SITE --> DOC["Docs"]:::section

    PRJ --> SUM["summary.md"]:::tbd
    PRJ --> MIS["mission.md"]:::page
    PRJ --> MET["method.md"]:::page
    PRJ --> GLS["glossary.md"]:::page

    PIP --> PPL["pipeline.md"]:::page
    PIP --> CAC["CACHE-manifest.md"]:::page

    ANA --> EDA["eda-2.html\n(embedded)"]:::page
    ANA --> RPT["report-1.html\n(embedded)"]:::page

    STO --> ST1["stories-1.qmd\n(RevealJS)"]:::tbd

    DOC --> RM["README.md"]:::page
```

> Note: Yellow nodes (italic) are files marked **TBD** — they must be created before the Publisher can complete the build.

---

## Publishing Orchestra Pipeline

How the four agents transform editorial intent into a rendered `_site/`.

```mermaid
flowchart TD
    H(["Human Editor"])

    subgraph PE["① Prompt Engineer"]
        direction TB
        PE1["Scans repo for\npublishable content"]
        PE2["Drafts editor.prompt.md"]
    end

    EPM["editor.prompt.md\n(editorial intent)"]
    HA(["Human: approve /\nedit editor.prompt.md"])

    subgraph ED["② Publishing Editor"]
        direction TB
        ED1["Resolves source paths"]
        ED2["Normalizes files → content/"]
        ED3["Writes publisher.prompt.md"]
    end

    CN["content/\n(normalized sources)"]
    PPM["publisher.prompt.md\n(build spec)"]
    HB(["Human: approve\npublisher.prompt.md"])

    subgraph PB["③ Publishing Publisher"]
        direction TB
        PB1["Scaffolds _quarto.yml"]
        PB2["Runs quarto render"]
    end

    QS(["questions.prompt.md\n(blockers, if any)"])
    SITE["_site/\n(rendered website)"]
    HC(["Human: review site"])

    H -->|starts pipeline| PE
    PE --> EPM
    EPM --> HA
    HA -->|approved| ED
    ED --> CN
    ED --> PPM
    PPM --> HB
    HB -->|approved| PB
    PB -->|stuck| QS
    QS -->|resolved| PB
    PB --> SITE
    SITE --> HC
    HC -->|changes needed| H
```
