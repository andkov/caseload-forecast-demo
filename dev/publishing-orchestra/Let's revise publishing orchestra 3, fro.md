Let's revise publishing orchestra 3, from what I have undertood after printing frontend-3.

 1) Interviewer should require that human authors initial.prompt.md for that frontend. 
 
 2) publishing-contract-template should contain a default architecture and possible/manadatory/expected componentts: 

 Nav Bar
 - index is the home page so it's  absent from the nav bar
 - Project
 - Pipeline
 - Analysis
 - Docs
 - Story (optional)
 - Materials (optional)
 - Philosophy (optional)

 Project, Pipeline, Analysis, Docs are manadatory/expected sections of the Nav bar. Without populating these, it's hard to argue that the project is mature enough to publish. 

 Every front end will be a static quarto website, fully portable. If a user want a single presentation, that's fine, but it must be set in the minimal context of: Project, Pipeline, Analysi, Docs. 

Project
 -- mission
 -- method
 -- glossary
 -- summary (composed by the Writer)

Pipeline
-- Pipeline Guide - parsimonious synthesis of ./README.md and ./manipulation/pipeline.md that gives a rounded introduction into understanding of the tasks and processes the generated RAW.  Calibrated to be accessible to casual analysts (I like the ballance struck in _frontend-1\content\pipeline\cache-manifest.md. But don't carry over the refernce to it in the publishing orchestra 3 specification). 
-- Cache-manifest - a verbatim copy of ./data-public/metadata/cache-manifest.md, which describes the data objects prepared by the ellis lane. 

Analysis 
-- EDA-2 - at least one EDA script must have been project (EDA-1 is reserved for working examples with mtcars)
-- Report-1 - at least one non-exploratory report that communicates current insights and valuable claims supported by evidence from EDA (and, optionally, modeling efforts). 

If the repo does not have at least these two reports, it's probably not mature enough to be published to a frontend. 


Docs
-- README (main, verbatim)
-- Site map (composed by writer)
-- Publisher notes (verbatim copy of the current publisher orchestra file in ./.github)

When user mentions talks or slides or presentations, these should go into Story in Navbar



