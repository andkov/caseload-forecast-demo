# Evaluating the C4 Model for Data Analysis Repositories

**Purpose**: Assess whether the [C4 model](https://c4model.com) is a good fit for describing the architecture of `andkov/caseload-forecast-demo` and, more broadly, for repositories that prioritize data analysis and reproducible research.

**Verdict**: C4 is a **useful but incomplete** framework for this class of project. Its top two levels (Context and Container) translate well and add genuine clarity. Its bottom two levels (Component and Code) offer diminishing returns for R/Quarto analysis repos. A practical adoption strategy treats C4 as a structural backbone and supplements it with data-flow and artifact-lineage diagrams that the model does not natively provide.

---

## What Is C4?

The C4 model, created by Simon Brown, provides four hierarchical levels for visualizing software architecture:

| Level | Name | Question Answered | Typical Audience |
|:------|:-----|:------------------|:-----------------|
| 1 | **Context** | What is the system and who interacts with it? | All stakeholders |
| 2 | **Container** | What are the major runtime/deployment units? | Technical team |
| 3 | **Component** | What are the key modules inside a container? | Developers, architects |
| 4 | **Code** | How is a specific component implemented? | Developers |

C4 also recognizes supplementary diagrams — deployment, dynamic (sequence), and data-flow views — that can be layered alongside the four core levels.

---

## Applying C4 to This Repository

### Level 1 — System Context

**Verdict: Good fit.**

A Context diagram immediately clarifies three things that are otherwise scattered across README, mission, and method documentation:

- **The system**: The caseload forecasting pipeline (Ferry → Ellis → Mint → Train → Forecast → Report).
- **Users**: Lead Analyst (primary), Analytics Team (report consumers), Infrastructure Lead (cloud migration).
- **External systems**: Alberta Open Data (CSV source), potential cloud targets (Azure ML, Snowflake ML), SharePoint/network drives (report delivery).

This level maps cleanly because the pipeline, despite being a collection of R scripts rather than a web application, still has clear boundaries, external data sources, and human actors. The existing mermaid flowchart in `README.md` and `manipulation/pipeline.md` partially serves this purpose but lacks the actor/system-boundary framing that a C4 Context diagram provides.

### Level 2 — Container

**Verdict: Good fit with adaptation.**

In C4, "containers" are independently deployable/runnable units. For this repository, the natural containers are:

| Container | Technology | Responsibility |
|:----------|:-----------|:---------------|
| `flow.R` orchestrator | R | Sequences pipeline execution |
| Pipeline scripts (`manipulation/`) | R | Ferry, Ellis, Mint, Train, Forecast stages |
| EDA reports (`analysis/eda-*/`) | R + Quarto | Advisory diagnostics (outside `flow.R`) |
| Forecast report (`analysis/report-1/`) | R + Quarto | Final deliverable (HTML) |
| SQLite staging database | SQLite | Ferry output, intermediate storage |
| Parquet data store (`data-private/derived/`) | Apache Parquet | Ellis output, Mint forge artifacts, forecast CSVs |
| Configuration (`config.yml`) | YAML | Pipeline parameters, `focal_date`, paths |

This level is valuable because it distinguishes things that the current documentation conflates: the orchestrator (`flow.R`) is not the same kind of thing as a pipeline script, and the Parquet store is not the same kind of thing as the SQLite staging database. A Container diagram makes these distinctions visible.

**Adaptation needed**: C4 assumes containers communicate via network protocols (HTTP, messaging). Here, containers communicate via the file system — scripts read and write Parquet/SQLite artifacts. The diagram notation needs to label arrows as "reads/writes Parquet" rather than "calls API," which is non-standard for C4 but perfectly legible.

### Level 3 — Component

**Verdict: Limited value.**

Inside each pipeline script, the internal structure is relatively flat: load packages → load data → transform → save output. R scripts in this project do not have the kind of modular component architecture (service classes, repositories, controllers) that C4 Level 3 is designed to expose.

Where Level 3 might add *some* value:

- **`2-ellis.R`**: Produces 11 distinct analysis-ready tables (wide + long variants for total, client type, family composition, regions, age, gender). A component diagram could map these as distinct transformation paths within the Ellis container.
- **`4-train-IS.R`**: Contains multiple model tiers (Naive, ARIMA, future subgroup disaggregation, ARIMA+xreg). Each tier could be treated as a component.
- **`scripts/` shared functions**: Helper functions (`common-functions.R`, `graph-presets.R`, modeling utilities) form a reusable component layer consumed by multiple containers.

For most other scripts, a component diagram would add diagram overhead without revealing structure that the script comments and docstrings do not already convey.

### Level 4 — Code

**Verdict: Not useful.**

C4 Level 4 (class/code diagrams) assumes object-oriented structure — classes, interfaces, inheritance. This repository is written in functional R with procedural scripts. Function-level documentation via roxygen headers and inline comments is the appropriate tool here, not UML class diagrams.

---

## Where C4 Falls Short for Data Analysis Repos

The C4 model was designed for **software systems** — applications with APIs, databases, message queues, and deployment infrastructure. Data analysis repositories have fundamentally different architectural concerns. The following gaps are significant:

### 1. Data Flow and Lineage

C4 diagrams show **structural containment** (what is inside what) and **dependencies** (what calls what). They do not natively represent:

- **Data lineage**: Which script produced which artifact, and which downstream script consumes it.
- **Schema evolution**: How the data shape changes from raw CSV (50,000 rows, wide format) through Ellis (11 tables, long + wide) to Mint (train/test splits, xreg matrices) to Forecast (point estimates + intervals).
- **Versioning bonds**: The `forge_hash` chain that links Mint → Train → Forecast artifacts.

This repository already has a lineage model (`forge_manifest.yml` → model registry → forecast manifest) that is better described by a **data lineage diagram** than by any C4 level.

### 2. Temporal Orchestration

C4 is a static structural model. It does not represent:

- **Execution order**: The `ds_rail` tibble in `flow.R` defines a strict sequence (Ferry → Ellis → Mint → Train → Forecast → Report).
- **Advisory vs. sequential relationships**: EDA "informs" Mint but is not a sequential dependency — a distinction the existing mermaid flowchart captures with dashed arrows.
- **Refresh cadence**: Monthly batch re-execution triggered by a new `focal_date`.

A **pipeline DAG** or **activity diagram** communicates these temporal aspects more effectively.

### 3. Artifacts as First-Class Citizens

In software systems, the important things are running processes and network connections. In data analysis repos, the important things are **artifacts**: Parquet files, `.rds` model objects, `forge_manifest.yml`, `model_registry.csv`, HTML reports. C4 treats data stores as passive containers, but in this project, the data artifacts *are* the primary outputs — not side effects of running code.

### 4. Reproducibility and Configuration

C4 does not address:

- **Determinism**: Fixed seeds, pinned dependencies (`renv.lock`), and `config.yml`-driven parameterization.
- **Environment reproducibility**: The relationship between `renv.lock`, `environment.yml`, and `install-packages.R`.
- **Invalidation rules**: Changing `focal_date` invalidates all Mint/Train/Forecast artifacts.

These are architectural concerns specific to reproducible research that no C4 level captures.

### 5. Audience Mismatch

C4's primary audience is software developers and architects. The primary audience for this repository's architecture documentation is **analysts with R/statistics backgrounds** who are learning cloud ML concepts. An over-engineered C4 diagram set could obscure rather than clarify, introducing vocabulary ("containers," "components") that conflicts with domain terms (containers in Docker, components in R packages).

---

## What This Repo Already Does Well Without C4

The existing documentation suite already addresses several concerns that C4 would target:

| Concern | Existing Documentation | C4 Equivalent |
|:--------|:----------------------|:--------------|
| System boundaries and actors | `ai/project/mission.md` (Stakeholders) | Context diagram |
| Pipeline stages and data flow | `README.md` mermaid flowchart, `manipulation/pipeline.md` | Container + Dynamic |
| Stage inputs/outputs/constraints | Method table in `ai/project/method.md` | Container arrows |
| Data schemas | `data-public/metadata/CACHE-manifest.md` | (No equivalent) |
| Artifact lineage | `forge_manifest.yml`, model registry | (No equivalent) |
| Execution orchestration | `flow.R` `ds_rail` table | Dynamic diagram |
| Configuration architecture | `config.yml` + guides | (No equivalent) |

The mermaid pipeline diagram in `README.md` is, in effect, a hybrid Context-Container-Dynamic diagram — it shows actors (data source), containers (scripts), and execution flow (arrows) in a single view. This pragmatic hybrid is arguably *more* informative for the target audience than three separate C4 diagrams would be.

---

## Recommendation: Selective Adoption

### Use C4 for

1. **Context diagram** — Add to project documentation to formalize the system boundary, external actors, and external systems. This is the single highest-value C4 artifact for this project. It would complement the existing pipeline flowchart by zooming out to show *who* and *what* interacts with the pipeline, not just *how* the pipeline flows internally.

2. **Container diagram** — Create when beginning cloud migration (Phase 2). Once the system spans on-prem R scripts *and* cloud services (Azure ML compute, model registry, Snowflake warehouses), the distinction between containers becomes architecturally meaningful. A Container diagram will clarify what stays local versus what migrates.

### Do Not Use C4 for

3. **Component diagrams** — The internal structure of R scripts is better documented with inline comments, roxygen headers, and the method documentation that already exists. A component diagram would add maintenance burden without proportional insight.

4. **Code diagrams** — Inappropriate for functional R codebases.

### Supplement C4 with

5. **Data lineage diagram** — A dedicated view showing artifact provenance: `CSV → staging.sqlite → *.parquet (Ellis) → forge/*.parquet (Mint) → *.rds (Train) → forecast.csv (Forecast) → report.html (Report)`. Annotate with `forge_hash` versioning bonds. This captures the architectural concern that matters most and that C4 cannot represent.

6. **Keep the pipeline DAG** — The existing mermaid flowchart is the right tool for showing execution order, advisory relationships, and stage dependencies. It should remain the primary architectural diagram.

---

## For Data Analysis Repos in General

The assessment above generalizes to other repositories that prioritize data analysis and reproducible research (e.g., RAnalysisSkeleton-derived projects, Targets/Drake pipelines, Quarto-based research compendia):

| C4 Level | Value for Data Analysis Repos | Rationale |
|:---------|:------------------------------|:----------|
| Context | **High** | Every project benefits from a clear boundary diagram showing data sources, users, and external systems. Analysts often skip this, assuming the audience knows the context. |
| Container | **Medium** | Useful when the system spans multiple runtimes (R + Python, local + cloud, database + file system). Less useful for single-language, single-machine pipelines. |
| Component | **Low** | Most analysis scripts are procedurally organized, not component-architected. Function libraries (`scripts/`) are the closest analogue, but documenting them as components adds formality without clarity. |
| Code | **None** | Functional R/Python scripts do not benefit from class diagrams. |

**The general prescription**: Use C4 Context as a standard practice. Use C4 Container when multi-platform complexity warrants it. Replace C4 Component and Code with domain-appropriate alternatives: data lineage diagrams, pipeline DAGs, artifact manifests, and schema documentation.

---

## Tooling Notes

If adopting C4 diagrams for this project, the following tools integrate well with the existing Quarto/Markdown documentation workflow:

- **Mermaid** (already in use): Supports C4 diagram syntax via [mermaid-c4](https://mermaid.js.org/syntax/c4.html). Can be embedded directly in `.qmd` and `.md` files. Native Quarto rendering support.
- **Structurizr DSL**: Simon Brown's official tooling. More expressive than Mermaid for C4, but requires a separate rendering step.
- **PlantUML C4 Extension**: The [C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML) library adds C4 stereotypes to PlantUML. Good for CI-generated diagrams but adds a Java dependency.
- **Draw.io / diagrams.net**: Manual drawing with C4 shape libraries. Good for one-off diagrams but not version-controlled as code.

**Recommendation**: Use Mermaid C4 syntax for any adopted diagrams, keeping them inline in Markdown files alongside the existing pipeline flowcharts. This maintains the documentation-as-code principle and requires no additional tooling.

---

## References

- Brown, S. (2023). *The C4 model for visualising software architecture*. <https://c4model.com>
- Brown, S. (2018). *Software Architecture for Developers* (Vol. 2). Leanpub.
- Wickham, H. (2015). *R Packages*. O'Reilly. — For comparison of how R project structure is typically documented.
- Wibeasley, W. *RAnalysisSkeleton*. <https://github.com/wibeasley/RAnalysisSkeleton> — The foundational pattern this repository adapts.
