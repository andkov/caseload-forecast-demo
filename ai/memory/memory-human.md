# Human Memory

Human decisions and reasoning. AI copilots are prohibited to edit this file.  

---

## 2026-03-17

Let's go back to designing Publishing Orchestra system. I created that frontend-1-map with Gemini help, but I don't like what it shows and how it captures the procedure and mental map of the process. 

Materials:  

- files in ./github/  
- files in ./_frontend-1/ (currente example, not proscriptive)
- analysis\frontend-1\initial.prompt.md - exmplifies how a human would start a conversation with Publishing Orchestrator to launch the production of _frontend-1
 
File analysis\frontend-1\README.md should be renamed into ./github/publishing-orchestra-1.md, that content does not belng in ./analysis/frontend-1/. Instead a more generic README.md should be written for ./analysis/frontend-1/README.md that explains that this folder is used to capture design instructions and evolution of specifications during implementating this particular frontend. 

Let's leave ./github/publishing-orchestra-1.md as is, and create ./github/publishing-orchestra-2.md that would capture the evolution of design of this agentic system. 

Incorporate the following feedback from reviewing the first draft:

- Publishing Publisher does not sound well and is somewhate misleading. A better name for this agent will be Publishing Printer. 
- A good conceptual anchor will be three states of analytic content: Raw, Edited, Printed. Raw is the state of a GitHub repo at some point in time (usually identified by a commit hash), in includes a lot of drafts, ongoing works, experiments, internal reports. 
- The main ./README.md tries to be useful landing page for developers and should be consulted for drafting the index page of /content produced by the editor. However, it's not suitable to use ./README.md as index page verbatim, human must be engaged to design the home page of the site. However, the main readme ./README.md should appear verbatim in the Docs section of the nav bar
- In fact, it could be one of the interview questions/ decision point that the conversation with the Publishing Orchestrator should confirm: produce the default list of .md and .html files to be displayed/printed verbatim and which should be sources for editorilizing and synthesis. 
- Publishing Editor must localize edited and human-approved contents that it creates to ./_frontend-N/content/ folder and nowhere else. If new files are to be created for the frontend-1, the Editor must create them in the ./_frontend-N/ and not the root of the project repository (source of RAW content)
- Pay particular attention to understanding and explaining inputs and outputs and what agents and instructions were engaged to moderate these processes and tasks. 



## 2026-03-16

Designed the first draft of the Publishing Orchestra using the artefacts created in a conversation with @oleksandkov. The prompt that launched an extensive interview with copilot is given below.

I would like to design a set of subagent or some orchestration set up that would help me take the repo with reproducible analytics and via human guidance publish a  front ent (a static website ) of the current state of the repo. 

Please reach out into C:\Users\andri\Documents\GitHub\caseload-forecast-demo-oleksandkov\data-public\raw\edit-publish-agents.md and C:\Users\andri\Documents\GitHub\caseload-forecast-demo-oleksandkov\data-public\raw\edit-publish-agents-1.md, as well as into C:\Users\andri\Documents\GitHub\caseload-forecast-demo-oleksandkov\.github to get started on the requirements and the existing converstaion.  (oleksandkov, main brachn, ac7a88fb97dcd9ab39ec3b89e99547f2a5f13dbf)

AFter you study the materials, please devise an interview with me (each answer is ingested and incorporated into the thinking before the next question is asked) to better understand what I want and envision with this publishing-orchestration

create a prompt to initiate the creation of subagents, instructions, prompts, SKILL and whatever else is necessary to implement and orchestrate publishgin of reproducible data science repo into a static website while preserve human input.



## 2026-02-23

### 6-report

Grapher, compose ./analysis/report-1/ report that would provide a reporting layer to the  lane 6 report as described in the method.md. Make sure the report references fore_manifest and model_registry and has a thorough knowledge of lane 3-mint, 4-train, and 5-forecast. Use eda-2 as a stylistic manuals (but also chekc /eda-1/eda-style-guide.md for more context if needed). Compose .R and .qmd that generate a hmtl document that reports on estimated models and is structured as inverted pyramid. The reader of the document must walk away with understanding what forecasting models exist (in this case only two, but we will be adding as we go further), how their forecast differs, and what uncovered evidence could be helpful in articulating a strategy for predicting the future with implication the policy.  

### test-ellis-cache

The script ./manipulation/2-test-ellis-cache.R should be renamed into ./manipulation/nonflow/test-ellis-cache.R, because while it has a distinct spot in the pipeline sequence (between lanes 2 and 3), it works as a support script (providing deterministic language to the agentic implementation of the testing). Rename and ensure that other places where it is referenced in the codebase are adjusted accordingling. (e.g. tasks, scripts, docs)

### 5-forecast

Data Engineer, compose 5-forecast-IS.R script that would implement lane 5 and create forecasting artefacts, according the method.md. Focus on the first two model teir only. Study commit 8a11f22220ca4dc63b624d5db24b34a87a726841 to inform your model hand-off. Anticipate the needs of the  lane 6 Report to create various reproducible documents from results of the mint-train-forecast processes.  Create a brief entry into memory-ai and a detailed account into the memory/log/. These documens should be useful to agents who will consume the products of the  lane 5 forecast.  

### 4-train  

Data Engineer, compose 4-train-IS.R script that would implement lane 4 and train models according to the method.md. Focus on the first two models only, to keep things simple. Consider how 5-model-IS.R will be consuming the project of the 4-train process and inform your design decision about model hand-off on this.  

## 2026-02-20

Data engineer, compose 3-mint-a.R that would output data of class "A" that support  

## 2026-02-18

### Create EDA-2

Follow the example of eda-1 and compose ./analysis/eda-2/ that would introduce the reader to the data (focus on total caseload and client type tables only, ignore other tables to keep it simple for now). Focus on timeseries for visuals, but use other graphs when necessary.  

### Create Ellis

Data Engineer, please compose ./manipulation/2-ellis.R that would input ./data-private/derived/open-data-is-1.sqlite that would create a set of tidy data tables to be written into ./data-private/derived/open-data-is-2.sqlite (a relational database that would be used as a starting point for subsequent analytic efforts). Follow the example of ./manipulation/example/ellis-lane-example.R. Make sure you verify each data type (see RAnalysisSkeleton). First, conduct a thorough exploration of the raw table and confirm your understanding of it with the human user. Wait for the confirmation of the list of table you will propose before creating it.  

### Create Ferry

Let's create `./manipulation/1-ferry.R` lane following the `./manipulation/ferry-lane-example.R` that would demonstrate the import from four (4) sources: 1) [URL](https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv) 2) CSV (data-public\raw\is-aggregated-data-april-2005-sep-2025.csv), 3) SQLite (data-public\raw\open-data-is-sep-2025.sqlite) and 4) SQL Server [RESEARCH_PROJECT_CACHE_UAT].[AMLdemo].[open_data_is_sep_2025]]). The product of the ferry should be a `./data-private/derived/open-data-is-1.sqlite` file that would contain the raw content of the input.  
The ferry lane will not do any transformations. Before writing data to db, it must demonstrate that the inputs from all four sources are identical and can be used interchangably.

## 2026-02-12

We need to design the ferry lane that would implement the import from four different sources: csv, url, sqlite and sql server. Before we compose this ferry script, let's create the sqlite and sqrver sources. Create an R script (`./manipulation/create-data-assets.R`) that would create 1) a sqlite db in `data-public/raw/` with identical contents as our csv data source and 2) table `AMLdemo`.open_data_is_sep_2025 on research_project_cache via ODBC, like you see in the example of ferry.  
