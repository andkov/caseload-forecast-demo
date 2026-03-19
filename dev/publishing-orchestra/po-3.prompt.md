
Let us create ./github/publishing-orchestra-3.md using the existing version .github\publishing-orchestra-2.md and integrating  our evolving understanding  in documents:
- dev\publishing-orchestra\po-3-draft.md
- _frontend-1 - the frontend created by the publishing-orchestra-2. Use as inspiration and study, not as intent.
- human user input given in this file

## First some random thoughts

RAW - product of analysts
Interviewer agent
checkpoint
Writer agent
EDITED
checkpoint
PRINTED

Interviewer: What do you want to say?
Writer: Here is what you are saying. 

RAW ---prob---> EDITED ---det---> PRINTED

RAW ---> EDITED  is a probabilistic lane that includes two phases: 

RAW ---> EDITED
Lanes:   
1) Angent: Interviewer. RAW + publishing-contract-template.md + publishing-interviewing.instructions.md + user input ---probabilistic,iterative---> publishing-contract.prompt.md 
- human checkpoint  
2) Agent: Writer. RAW + publishing-contract.prompt.md + publishing-rules.instructions.md ---prob---> (edited_content + _quarto.yml + support files)

EDITED ---det---> PRINTED
3) quarto render  ---det---> PRINTED
- human checkpoint 


Interviewer wants to understand the audience, the message, and what is important to the human who composes the frontend-N. What context is available in the RAW? What components deserve special attention? What do you want to say  and to whom? 

Writer takes up the pen and writes words down. Three ways: 1) verbatim copy 2) adapted form 3) composed synthesis. Continuum from verbatim copy to original content. 

Human can intervene by/ Human checkpoints: 
- editing publishing-contract.prompt.md (manually or via Interviewer agent or generic agent)
- editing edited_content contents (manually or via agent)


Objective of the Interviewer: Your task is to transform raw human intent and repository evidence into a singular, high-fidelity contract: publishing-contract.prompt.md. You must approach this task with the "spiritual goal" of an analyst: seeking the most parsimonious path from available evidence to desired knowledge.


## Language on the Writer Lane

Publishing Rules & Implementation Guardrails (v3)
### 1. Core Principles of Construction
The Self-Containment Rule: At the conclusion of Phase 2, the edited_content/ folder must be fully autonomous. All images, data artifacts, and includes must be co-located. No relative paths may point outside this folder.

Epistemological Grounding: For COMPOSED content, every factual claim must be traceably derived from the Raw repository state. The Writer must not "hallucinate" data results not found in the source files. WHen making claims about what the data says, give the reference what RAW file support it.

Formatting over Content: For VERBATIM and TRANSFORMED types, the Writer's priority is technical legibility, not editorial revision.

### 2. Writing Protocols by Type

1. Direct Line
2. Technical Bridge
3. Narrative Bridge

Type 1: Verbatim & Redirected (Direct Line)
Protocol [VERBATIM]:

Action: Perform a bitwise-adjacent copy of the source .md or .qmd to the appropriate subfolder in edited_content/.

Formatting: Ensure a standard YAML frontmatter block (title, date, author) exists. If missing, generate it based on file headers.

Protocol [REDIRECTED]:

Action: Create a "stub" .qmd file. Use Quarto's include or an HTML meta-refresh to point to the target .html.

Hook: Register a post-render R script to ensure the heavy .html source is moved into the final _site/ directory.

Type 2: Adapted & Transformed (Technical Bridge)
Protocol [TRANSFORMED]:

Link Rewriting: Convert all internal repository paths (e.g., analysis/data/) to relative website paths (e.g., ../data/).

Shortcode Injection: Replace complex code blocks (like Mermaid diagrams) with {{< include >}} shortcodes to maintain Quarto compatibility.

Sanitization: Automatically strip developer-centric noise: TODO lists, local file-system paths, and internal-only comments.

Type 3: Synthesized & Composed (Narrative Bridge)
Protocol [COMPOSED]:

Contextual Synthesis: Read the "Brief" in the publishing-contract.prompt.md to identify the Intent, Goal, and Spirit.

Narrative Construction: Assemble a coherent story (e.g., a landing page or project summary) by weaving together findings from multiple reports.

Audience Adaptation: If the contract specifies a "different audience," paraphrase existing technical evidence into the appropriate register (e.g., executive vs. technical peer).

### 3. Asset & Link Management
Image Co-location: Any image referenced in a page must be copied to a local assets/ or images/ directory within edited_content/.

Broken Link Prevention: The Writer must verify that every internal cross-reference in the edited_content/ folder resolves. If a link points to a file excluded by the contract, it must be converted to plain text or flagged.

### 4. The _quarto.yml Generation
The Writer must generate the project configuration using these strict rules:

Explicit Render List: Do not use wildcards. Every file listed in the publishing-contract.prompt.md must be explicitly named in the render: list.

Navigation Mirroring: The navbar or sidebar structure must exactly match the hierarchical sections defined in the contract.

Hook Documentation: Any pre-render or post-render R scripts must include a header comment explaining their purpose in the pipeline.

### 5. Error Handling & Inspection
The Flagging Protocol: If a COMPOSED brief is ambiguous or a source file is missing, the Writer must complete the rest of the assembly and append a BUILD_REPORT.md to edited_content/ highlighting the issues.

Reconciliation: After rendering, verify that the number of .html files in _site/ matches the number of intended pages in the contract.




## Other comments

- let's purge the contents of .github/ (except those in the root: .github/*.md) when we create a publishing-orchestra-3 and its associated .github/ files. I saved a copy of these in git and elsewhere, so let's keep it clean. 
- related to previous. Make sure the new .github/publishing-orchestra-3.md is has a file map describing the components and agents of the orchestra as file map diagrams and ascii diagrams and dendrograms.
- Phases (1-2-3) shold denote the movement between states of rest at whcih humans can inspect the language of the artefacts. 