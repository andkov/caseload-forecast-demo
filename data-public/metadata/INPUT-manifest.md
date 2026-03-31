# INPUT Manifest: Alberta Income Support Aggregated Caseload Data

Provides definitive information and metadata about the raw input file used in this project — before it is ingested by the Ferry lane and transformed by Ellis.

---

## Purpose

This manifest documents the **raw source data** downloaded from the Alberta Open Government portal and used as the entry point for the caseload forecasting pipeline. It describes the file format, schema, categorical values, temporal coverage, and known data quality issues in the **original, untransformed CSV** — the canonical input before any Ferry or Ellis processing.

For documentation of the **analysis-ready tables** produced after transformation, see [`CACHE-manifest.md`](CACHE-manifest.md).

---

## Dataset Summary

| Field                    | Value |
|:-------------------------|:------|
| **Dataset Name**         | Income Support Caseload |
| **Publisher**            | Alberta Assisted Living and Social Services (ALSS), Government of Alberta |
| **License**              | [Open Government Licence – Alberta](https://open.alberta.ca/licence) |
| **Open Data Portal**     | <https://open.alberta.ca/opendata/income-support-aggregated-caseload-data> |
| **Dataset UUID**         | `e1ec585f-3f52-40f2-a022-5a38ea3397e5` |
| **Resource UUID**        | `4f97a3ae-1b3a-48e9-a96f-f65c58526e07` |
| **Direct CSV URL**       | <https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv> |
| **Local Copy**           | `data-public/raw/is-aggregated-data-april-2005-sep-2025.csv` |
| **Temporal Coverage**    | April 2005 – September 2025 (246 calendar months) |
| **Total Data Rows**      | 3,722 (excluding 2 header rows) |
| **Update Frequency**     | Monthly (new months appended as data becomes available) |
| **Geography**            | Province of Alberta (all rows) |

---

## Raw File Format

The CSV file uses a **two-row header** pattern:

- **Row 1** (title): `"Alberta Assisted Living and Social Services\nIncome Support Caseload"` — a merged label spanning the first column; all other columns are empty.
- **Row 2** (column headers): `Ref_Date`, `Geography`, `Measure Type`, `Measure`, `Value` — followed by 9 trailing empty columns.
- **Rows 3+** (data): One observation per row. Each row reports a single `(month × measure type × measure)` combination.

---

## Raw Column Schema

| Column         | Raw Name       | Type (raw)  | Description |
|:---------------|:---------------|:------------|:------------|
| `ref_date`     | `Ref_Date`     | Character   | Reference month in `YY-MMM` format (e.g., `05-Apr` = April 2005). Two-digit year; month as 3-letter abbreviation. |
| `geography`    | `Geography`    | Character   | Administrative geography. Constant value: `"Alberta"` for all rows. |
| `measure_type` | `Measure Type` | Character   | Dimension category — one of 6 values (see [Measure Types](#measure-types)). Groups related measures under a common analytical theme. |
| `measure`      | `Measure`      | Character   | Specific breakdown within the measure type (e.g., `"ETW - Working Total"` within `"Client Type Level"`). See [Measure Values by Type](#measure-values-by-type). |
| `value`        | `Value`        | Character   | Caseload count as a formatted string: comma-separated integer (e.g., `" 27,969 "`) with leading/trailing whitespace. Suppressed cells (small counts protected for privacy) appear as `" -   "`. |

### Notes on Raw Column Formats

- **`ref_date`** uses a non-standard `YY-MMM` format requiring custom parsing. The two-digit year is unambiguous for this dataset (all dates fall within 2000–2099).
- **`value`** requires cleaning: trimming whitespace, removing comma separators, and handling the suppression marker (`" -   "`) which represents small counts protected for privacy.
- **Trailing empty columns**: The raw CSV has 13 columns total — 5 meaningful + 8 empty.

---

## Measure Types

The `Measure Type` column classifies each row into one of six reporting dimensions. These dimensions were added progressively over time (see [Temporal Phases](#temporal-phases)).

| Measure Type         | Raw Rows | Time Span          | Description |
|:---------------------|:--------:|:-------------------|:------------|
| `Total Caseload`     | 84       | Apr 2005 – Mar 2012| Standalone total caseload (Phase 1 only; superseded by sub-totals in later phases) |
| `Client Type Level`  | 810      | Apr 2012 – Sep 2025| Caseload by employment readiness classification |
| `Family Composition` | 811      | Apr 2012 – Sep 2025| Caseload by household/family structure |
| `ALSS Regions`       | 720      | Apr 2018 – Sep 2025| Caseload by administrative service region |
| `Average Age`        | 1,056    | Apr 2020 – Sep 2025| Caseload by client age group |
| `Client Gender`      | 240      | Apr 2020 – Sep 2025| Caseload by self-identified gender |

**Important**: From April 2012 onward, `Total Caseload` is no longer reported as a standalone measure type. The total for that period must be derived from the `"Client Caseload Total"` row within `Client Type Level`.

---

## Measure Values by Type

### `Total Caseload`

| Measure Value    | Description |
|:-----------------|:------------|
| `Total Caseload` | Total number of active Income Support cases for that month (Alberta-wide) |

### `Client Type Level`

Classifies clients by employment readiness and program designation. This dimension was introduced as part of the Alberta Works reform in April 2012.

| Measure Value                                    | Cleaned Name                    | Description |
|:-------------------------------------------------|:--------------------------------|:------------|
| `ETW - Working Total`                            | ETW Working                     | Clients classified as Expected to Work who are currently employed but earning insufficient income for self-sufficiency |
| `ETW - Not Working (Available for Work) Total`   | ETW Available for Work          | ETW clients actively seeking employment and available for work |
| `ETW - Not Working (Unavailable for Work) Total` | ETW Unavailable for Work        | ETW clients temporarily unable to work (short-term illness, caregiving, training) |
| `BFE - Total`                                    | BFE                             | Clients with Barriers to Full Employment — significant long-term barriers (chronic health conditions, disabilities, complex life circumstances) |
| `Client Caseload Total`                          | Total                           | Sum of all four client types — serves as the provincial total from Apr 2012 onward |

**Client Type Definitions:**

- **Expected to Work (ETW)**: Clients assessed as able to participate in employment activities. Subdivided by whether they are currently working, available for work but not working, or temporarily unavailable. ETW clients are generally expected to pursue employment and may receive income supplementation for low earnings.
- **Barriers to Full Employment (BFE)**: Clients facing significant, often long-term, barriers that preclude full-time employment. Barriers may include chronic physical or mental health conditions (of more than six months' duration), caregiving responsibilities, or other life circumstances. BFE clients generally receive higher benefit levels reflecting more complex needs.

### `Family Composition`

Classifies clients by household structure. Introduced April 2012.

| Measure Value                | Cleaned Name             | Description |
|:-----------------------------|:-------------------------|:------------|
| `Single Total`               | Single                   | Single adults without dependent children |
| `Single Parent Total`        | Single Parent            | Single-adult households with dependent children |
| `Couples with Children Total`| Couples with Children    | Two-adult households (married or common-law) with dependent children |
| `Childless Couples Total`    | Childless Couples        | Two-adult households without dependent children |
| `All Types Total`            | Total                    | Sum of all four family types |

### `ALSS Regions`

Caseload by Alberta Assisted Living and Social Services (ALSS) administrative service region. Regional data added April 2018.

| Measure Value       | Description |
|:--------------------|:------------|
| `Calgary`           | Calgary metropolitan area |
| `Central`           | Central Alberta, anchored by Red Deer |
| `Edmonton`          | Edmonton metropolitan area (provincial capital) |
| `North Central`     | Northern central Alberta, Grande Prairie area — **renamed "Unknown" effective January 2022** |
| `North East`        | North-eastern Alberta, including oil sands region (Fort McMurray, Cold Lake) |
| `North West`        | North-western Alberta, Peace Country (Peace River, High Prairie) |
| `South`             | Southern Alberta, including Lethbridge and Medicine Hat |
| `Unknown`           | Unspecified/unassigned region — introduced January 2022, coinciding with discontinuation of `North Central` label (likely reflects a postal code tracking update) |
| `All Regions Total` | Provincial total across all regions |

**Note on North Central → Unknown**: The `North Central` region label was present from April 2018 through December 2021. Starting January 2022, it was replaced by `Unknown`. The reason for this label change is not documented in the source data. Analysts should treat these as a potential reporting change rather than a true geographic boundary shift.

### `Average Age`

Age distribution of active caseload. Introduced April 2020. Uses five-year bins for ages 18–59, then single-year bins for ages 60–64, and an open-ended top bin.

| Measure Value    | Description |
|:-----------------|:------------|
| `Age 18 - 19`    | Clients aged 18–19 (youth transitioning to adulthood) |
| `Age 20 - 24`    | Clients aged 20–24 |
| `Age 25 - 29`    | Clients aged 25–29 |
| `Age 30 - 34`    | Clients aged 30–34 |
| `Age 35 - 39`    | Clients aged 35–39 |
| `Age 40 - 44`    | Clients aged 40–44 |
| `Age 45 - 49`    | Clients aged 45–49 |
| `Age 50 - 54`    | Clients aged 50–54 |
| `Age 55 - 59`    | Clients aged 55–59 |
| `Age 60`         | Clients aged exactly 60 (single-year bin) |
| `Age 61`         | Clients aged exactly 61 |
| `Age 62`         | Clients aged exactly 62 |
| `Age 63`         | Clients aged exactly 63 |
| `Age 64`         | Clients aged exactly 64 |
| `Age 65 +`       | Clients aged 65 and over (open-ended top bin) |
| `All Ages Total` | Sum across all age bins |

**Note on bin granularity**: The shift to single-year bins at ages 60–64 reflects policy relevance of the transition to federal pension programs (CPP becomes available at age 60; OAS at age 65).

### `Client Gender`

Gender distribution of active caseload. Introduced April 2020.

| Measure Value      | Description |
|:-------------------|:------------|
| `Female`           | Clients self-identifying as female |
| `Male`             | Clients self-identifying as male |
| `Other`            | Clients self-identifying outside the binary (non-binary, two-spirit, other gender identities) |
| `All Gender Total` | Sum across all gender categories |

**Note on `Other` suppression**: The `Other` category column is present in the raw data from April 2020, but values are suppressed (` -   `) through July 2022 due to small counts. The first reportable (non-suppressed) value is August 2022.

---

## Temporal Phases

Alberta's Income Support reporting progressively added dimensional breakdowns over five phases. Each new phase adds dimensions without removing prior ones.

| Phase | Period               | Months | Dimensions Available                                    |
|:-----:|:---------------------|:------:|:--------------------------------------------------------|
| 1     | Apr 2005 – Mar 2012  | 84     | `Total Caseload` only                                   |
| 2     | Apr 2012 – Mar 2018  | 72     | + `Client Type Level`, `Family Composition`             |
| 3     | Apr 2018 – Mar 2020  | 24     | + `ALSS Regions`                                        |
| 4     | Apr 2020 – Mar 2022  | 24     | + `Average Age`, `Client Gender`                        |
| 5     | Apr 2022 – Sep 2025  | 42     | + `Other` gender category (non-suppressed from Aug 2022)|

**Total**: 246 calendar months from April 2005 through September 2025.

---

## Known Data Quality Issues

### 1. November 2020 — Family Composition Duplicate Row

- **Issue**: The raw CSV contains two rows for November 2020 with `Measure Type = "Family Composition"` and `Measure = "All Types Total"`, reporting two different values: 48,850 (incorrect) and 44,850 (corrected).
- **Cause**: Appears to be a correction published in a subsequent release, with the erroneous row left in the file.
- **Affected raw rows**: 2 rows at `date = 2020-11-01`, `Measure Type = "Family Composition"`, `Measure = "All Types Total"`.

### 2. November 2020 — Average Age Total Mismatch

- **Issue**: The `Average Age / All Ages Total` row for November 2020 reports 48,850, but the sum of all individual age-bin rows for that month is 23,480 — a discrepancy of ~25,000.
- **Cause**: The `All Ages Total` value appears to be a data entry error (likely a transposition from the incorrect Family Composition total above).
- **Affected raw row**: 1 row at `date = 2020-11-01`, `Measure Type = "Average Age"`, `Measure = "All Ages Total"`, `Value = " 48,850 "`.

### 3. Suppressed Values

- **Pattern**: Small counts are privacy-protected by replacing the numeric value with `" -   "` (a hyphen with surrounding whitespace).
- **Scope**: Primarily affects the `Other` gender category before August 2022, and occasional small-count regional or age-group cells.
- **Implication**: Sub-category totals may not sum precisely to the reported `Total` row for months with suppressed cells.

---

## Access and Licensing

### Download

The dataset is publicly available through the Alberta Open Government Portal under the **Open Government Licence – Alberta**, which permits free use, modification, and redistribution with attribution.

**Portal page**: <https://open.alberta.ca/opendata/income-support-aggregated-caseload-data>

**Direct CSV download**:

```
https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv
```

**Local cached copy** (committed to repository for offline reproducibility):

```
data-public/raw/is-aggregated-data-april-2005-sep-2025.csv
```

### Attribution

> Alberta Assisted Living and Social Services. *Income Support Caseload*. Government of Alberta Open Data Portal. <https://open.alberta.ca/opendata/income-support-aggregated-caseload-data>. Licensed under the Open Government Licence – Alberta.

### License

The **Open Government Licence – Alberta** (<https://open.alberta.ca/licence>) permits:

- Copying, publishing, distributing, and transmitting the data
- Adapting the data (including commercial use)

Conditions: Acknowledge the source (Government of Alberta) and note any modifications.

---

## Pipeline Position

This file is the **sole external data source** for the entire forecasting pipeline.

---

## Sources and Contributions

The following sources were consulted when compiling this manifest. Each source's specific contribution is noted.

1. **Alberta Open Government Portal — Income Support Caseload dataset page**
   - URL: <https://open.alberta.ca/opendata/income-support-aggregated-caseload-data>
   - Contribution: Dataset name, publisher, UUID, license, direct download URL, format availability

2. **Open Government Canada — Federal mirror of the same dataset**
   - URL: <https://open.canada.ca/data/en/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5>
   - Contribution: Dataset UUID confirmation, publisher attribution, ETW/BFE client type descriptions

3. **Alberta Open Government Licence**
   - URL: <https://open.alberta.ca/licence>
   - Contribution: License terms and attribution requirements

4. **Government of Alberta — Income Support program page**
   - URL: <https://www.alberta.ca/income-support>
   - Contribution: Program overview, eligibility criteria, ETW/BFE definitions, benefit structure

5. **Maytree — Social Assistance Summaries: Alberta**
   - URL: <https://maytree.com/changing-systems/data-measuring/social-assistance-summaries/alberta/>
   - Contribution: ETW/BFE client classification definitions, program context

6. **Alberta Assisted Living and Social Services — Open Data (data visualization PDF, June 2025)**
   - URL: <https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/07b7a69b-af57-4227-92ad-2187959a0bf8/download/is-data-visualization-june-2025.pdf>
   - Contribution: Publisher name confirmation (ALSS), regional structure context

7. **Raw CSV file (direct inspection)**
   - Path: `data-public/raw/is-aggregated-data-april-2005-sep-2025.csv`
   - Contribution: Column names, row counts, unique categorical values, date ranges per measure type, suppression pattern, two-row header structure, trailing empty columns

