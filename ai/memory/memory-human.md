# Human Memory

Human decisions and reasoning.

---

# 2026-02-12

We need to design the ferry lane that would implement the import from four different sources: csv, url, sqlite and sql server. Before we compose this ferry script, let's create the sqlite and sqrver sources. Create an R script (./manipulation/create-data-assets.R) that would create 1) a sqlite db in data-public/raw/ with identical contents as our csv data source and 2) table _TEST.open_data_is_sep_2025 on research_project_cache via ODBC, like you see in the example of ferry