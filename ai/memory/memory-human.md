# Human Memory

Human decisions and reasoning. AI copilots are prohibited to edit this file. 

---




# 2026-02-18

## Create Ellis

Data Engineer, please compose ./manipulation/2-ellis.R that would input ./data-private/derived/open-data-is-1.sqlite that would create a set of tidy data tables to be written into ./data-private/derived/open-data-is-2.sqlite (a relational database that would be used as a starting point for subsequent analytic efforts). Follow the example of ./manipulation/example/ellis-lane-example.R. Make sure you verify each data type (see RAnalysisSkeleton). First, conduct a thorough exploration of the raw table and confirm your understanding of it with the human user. Wait for the confirmation of the list of table you will propose before creating it. 



## Create Ferry

Let's create `./manipulation/1-ferry.R` lane following the `./manipulation/ferry-lane-example.R` that would demonstrate the import from four (4) sources: 1) URL (https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv) 2) CSV (data-public\raw\is-aggregated-data-april-2005-sep-2025.csv), 3) SQLite (data-public\raw\open-data-is-sep-2025.sqlite) and 4) SQL Server [RESEARCH_PROJECT_CACHE_UAT].[AMLdemo].[open_data_is_sep_2025]]). The product of the ferry should be a `./data-private/derived/open-data-is-1.sqlite` file that would contain the raw content of the input. 
The ferry lane will not do any transformations. Before writing data to db, it must demonstrate that the inputs from all four sources are identical and can be used interchangably.


# 2026-02-12

We need to design the ferry lane that would implement the import from four different sources: csv, url, sqlite and sql server. Before we compose this ferry script, let's create the sqlite and sqrver sources. Create an R script (`./manipulation/create-data-assets.R`) that would create 1) a sqlite db in `data-public/raw/` with identical contents as our csv data source and 2) table `AMLdemo`.open_data_is_sep_2025 on research_project_cache via ODBC, like you see in the example of ferry.