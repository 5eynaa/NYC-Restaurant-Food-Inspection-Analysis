# NYC Restaurant Inspection Analysis — SQL Data Cleaning & Exploratory Data Analysis (Public Health / Government)

## Executive Summary

New York City runs tens of thousands of restaurant inspections every year, but inspection resources are finite. This project takes the public Department of Health and Mental Hygiene New York City Restaurant Inspection Results dataset and asks where food safety risk actually concentrates, and where the city could focus its effort to the greatest effect. Using MySQL, 288,888 rows were imported, cleaned and standardised down to a reliable 285,177 rows, then used to answer four analytical questions covering violation patterns, cuisine and neighbourhood risk, and trends over time.

The headline findings: two violations (10F, non food contact surface issues, and 08A, conditions conducive to pests) dominate every borough in every year, and both are structural rather than behavioural. A small number of neighbourhoods and cuisine groups carry consistently higher risk, with average scores well above the citywide norm. From this, the analysis sets out where future inspection effort could be targeted. All four visualisations were built in Power BI.

The data is public and the questions are the author's own framing, used to demonstrate an end to end analytical workflow rather than to fulfil a commissioned brief.

## Business Problem

The DOHMH inspects every restaurant in the city and records violations, scores and letter grades. With limited inspectors and limited budget, the practical problem is one of prioritisation: which violations matter most, which areas and cuisines are struggling, how performance is moving over time, and therefore where future effort would have the greatest impact. This project works through that problem in four stages, framed as the following questions:

- **Question 1:** Which violations are most common and where do they occur most frequently?
- **Question 2:** Which cuisines and neighbourhoods have the lowest food safety performance?
- **Question 3:** How do restaurant grades and violations vary across boroughs and over time?
- **Question 4:** Where should the city focus inspections, policies, or education to improve food safety?

<!-- ============================================================= -->
<!-- IMAGE PLACEHOLDER 1 — OVERVIEW / DASHBOARD                     -->
<!-- Paste your main Power BI dashboard or overview visual here.    -->
<!-- Save the file into the /visuals folder, then replace the line  -->
<!-- below with: ![Overview dashboard](visuals/your-filename.png)   -->
<!-- ============================================================= -->


## Methodology

The full workflow was carried out in MySQL, from raw import through to the analytical queries that answer each question.

1. **Data cleaning** — duplicate removal, a full blank and NULL audit across all 27 columns, canonical standardisation of violation descriptions and street names, and conversion of date columns to proper `DATE` types.
2. **Exploratory data analysis** — four sets of aggregation queries, using window functions and CTEs to rank and segment violations, scores and grades by borough, cuisine, neighbourhood (NTA) and year.
3. **Visualisation** in Power BI to present the findings.

The detailed step by step write ups, with every query and the reasoning behind each decision, are linked below:

- [Data cleaning write up](docs/data-cleaning.md)
- [Exploratory analysis write up](docs/exploratory-analysis.md)
- [All cleaning SQL](sql/01_cleaning.sql)
- [All analysis SQL](sql/02_analysis.sql)

## Skills

**SQL (MySQL):** `LOAD DATA INFILE` bulk import, `ROW_NUMBER()` window functions, Common Table Expressions (CTEs), `PARTITION BY`, `CASE WHEN` conditional aggregation, lookup table creation and joins for standardisation, `REGEXP_REPLACE` for pattern based cleaning, `STR_TO_DATE` and `ALTER TABLE` for date type conversion, blank versus NULL auditing, `COUNT(column)` versus `COUNT(*)` for accurate denominators.

**Power BI:** data visualisation, dashboard design, heatmaps, bubble maps, trend line charts.

## Data Cleaning

The dataset arrived with the usual problems of a large public extract: duplicate rows, placeholder dates, inconsistent violation wording, missing geographic data and date columns stored as text. Each was investigated before any change was made, following the principle of auditing first and only acting once the cause was understood. The headline steps:

- **Duplicates** — removed using a three layer `ROW_NUMBER()` approach partitioned across all columns.
- **Ghost records** — 3,699 rows carrying a `01/01/1900` placeholder date were confirmed as invalid against the official data dictionary and deleted, reducing the table to 285,177 rows.
- **Blank audit** — a single `CASE WHEN` query counted blanks and NULLs across all 27 columns at once, sorting them into healthy columns, expected blanks (grades that are blank by design), and blanks needing action.
- **Violation standardisation** — a lookup table kept the most frequent (most recently standardised) description per violation code, collapsing duplicate wordings down to one version each.
- **Geographic and phone columns** — missing values investigated in subsets and converted to NULL where appropriate, with an entirely empty column dropped.
- **Street name standardisation** — abbreviations, typos and compass directions corrected with `REGEXP_REPLACE`, with careful word boundary handling to avoid corrupting valid names.
- **Date conversion** — three date columns converted from text to proper `DATE` types with `STR_TO_DATE` and `ALTER TABLE`, unlocking the time series analysis in Question 3.

The full detail, including every query, every verification step and the reasoning behind each decision, is in the [data cleaning write up](docs/data-cleaning.md).

## Exploratory Analysis & Results

### Question 1 — Which violations are most common, and where?

Built incrementally from a citywide overview to a per borough top five, using a CTE with `ROW_NUMBER()` partitioned by borough, then extended with the critical flag for severity.

**Key finding:** violation **10F** (non food contact surface issues, 40,037 occurrences) and **08A** (harborage conditions conducive to pests, 27,298 occurrences) rank first and second in every single borough without exception. Both are classified Not Critical, but critical violations such as 06D (food contact surface not sanitised), 02G (cold food held above temperature) and 04L (evidence of mice) consistently appear in ranks three to five. Frequency does not equal severity.

<!-- ============================================================= -->
<!-- IMAGE PLACEHOLDER 2 — QUESTION 1 VISUAL                        -->
<!-- Paste your Question 1 Power BI visual here.                    -->
<!-- Save into /visuals, then replace the line below with:          -->
<!-- ![Question 1 — most common violations](visuals/your-file.png)  -->
<!-- ============================================================= -->

<img width="671" height="566" alt="image" src="https://github.com/user-attachments/assets/d97afd34-d64d-4eec-9a8e-9bde39337ccf" />

100% stacked bar chart showing the top 5 violations per borough by count and percentage. Each bar represents a borough, segmented by the top 5 violation codes for that borough, displaying both the violation count and percentage share. 10F dominates every borough. Total violation counts are displayed above each bar. 8 unique violation codes appear across the chart as the top 5 codes vary between boroughs


### Question 2 — Which cuisines and neighbourhoods perform worst?

Performance was measured with three complementary metrics rather than one: average score, critical violation percentage, and grade distribution (A to C plus the administrative N, Z and P statuses), all calculated with `CASE WHEN` aggregation and the correct `COUNT(GRADE)` denominator.

**Key finding:** with the raw cuisine labels grouped into broader categories (for example Bangladeshi, Pakistani and Indian folded into **South Asian**, and the various African cuisines into **African**), two groups stand out as the worst performers by average score across multiple boroughs. **South Asian** is the highest scoring group in four of the five boroughs, peaking in Queens (average score 37.1 across 2,415 inspections) and Brooklyn (34.4 across 1,488). **African** is the single worst cuisine/borough combination in the dataset, in Manhattan (38.6 across 574 inspections) and again high in the Bronx (34.2 across 434). At the other end, high volume groups like American and Beverages & Snacks score consistently well, driven by chains with standardised processes. Grouping the cuisines this way made the heatmap far more readable than the original long tail of individual labels, while still surfacing the same underlying risk concentration.

<!-- ============================================================= -->
<!-- IMAGE PLACEHOLDER 3 — QUESTION 2 VISUAL (CUISINE HEATMAP)      -->
<!-- Paste your Question 2 cuisine standardisation heatmap here.    -->
<!-- Save into /visuals, then replace the line below with:          -->
<!-- ![Question 2 — cuisine heatmap](visuals/your-file.png)         -->
<!-- ============================================================= -->

<img width="731" height="560" alt="image" src="https://github.com/user-attachments/assets/0fde2b73-5697-4653-a3ae-8bef227d01b1" />


### Question 3 — How do grades and violations vary by borough and over time?

`INSPECTION DATE` was chosen as the time dimension (the date the inspector actually visited), at year level granularity for a clean 2022 to 2025 window.

**Key finding:** Grade A counts grow year on year across all boroughs from 2022 to 2024, suggesting genuine improvement. Manhattan carries the highest raw counts throughout, reflecting restaurant density rather than performance, so borough comparison needs rates rather than raw counts. Violation 10F grows substantially year on year up to 2024 in every borough. The 2025 figures are lower across the board because the dataset was extracted partway through the year, a caveat that must accompany any trend chart.

<!-- ============================================================= -->
<!-- IMAGE PLACEHOLDER 4 — QUESTION 3 VISUAL (GRADE TREND LINES)    -->
<!-- Paste your Question 3 grade trend line chart(s) here.          -->
<!-- Save into /visuals, then replace the line below with:          -->
<!-- ![Question 3 — grade trends over time](visuals/your-file.png)  -->
<!-- ============================================================= -->

<img width="476" height="594" alt="image" src="https://github.com/user-attachments/assets/c2df5be7-7126-4c67-a28a-10d97b2ac8a5" />


<img width="467" height="592" alt="image" src="https://github.com/user-attachments/assets/24ed98bb-bc21-4777-9272-3fadf83826a2" />


<img width="509" height="572" alt="image" src="https://github.com/user-attachments/assets/d1b19e23-ecc2-4ee5-955c-bf78de05069d" />


### Question 4 — Where should the city focus?

A synthesis question, drawing on Questions 1 to 3 plus a neighbourhood (NTA) level query to pinpoint where risk concentrates geographically.

<!-- ============================================================= -->
<!-- IMAGE PLACEHOLDER 5 — QUESTION 4 VISUAL (WORST NTAs BUBBLE MAP)-->
<!-- Paste your Question 4 worst-NTA bubble map here.               -->
<!-- Save into /visuals, then replace the line below with:          -->
<!-- ![Question 4 — worst NTAs bubble map](visuals/your-file.png)   -->
<!-- ============================================================= -->

<img width="729" height="578" alt="image" src="https://github.com/user-attachments/assets/6a11a8ad-0f66-4f99-b005-52f5b1cf6399" />


## Recommendations

Based on the analysis, the following is where the city could focus its effort in future:

- **Where to inspect**: concentrate increased inspection frequency and proactive enforcement in the Bronx (particularly Allerton-Pelham Gardens, Woodlawn-Wakefield and Fordham South) and Queens (particularly Elmhurst-Maspeth and Flushing), where high average scores and critical violation rates are sustained across large restaurant populations.
- **Which violations to address**: violations 10F (non food contact surface issues) and 08A (conditions conducive to pests) dominate every borough and grow year on year. Both are structural and infrastructure related rather than one-off behavioural lapses, so simply citing them again at the next inspection changes little. The city would need to find a way to tackle these specific violations directly in the worst affected areas, whether through policy, better operator education, or another route. Identifying the exact violations and where they cluster is the contribution this analysis makes; deciding the precise mechanism is the natural next step.
- **Where the cuisine risk concentrates**: the South Asian and African cuisine groups carry the highest average scores across several boroughs, particularly in Queens, Brooklyn, Manhattan and the Bronx. These are the groups and areas where targeted support would have the most effect.

## Next Steps & Limitations

**Limitations:**

- The 2025 data is partial (extracted September 2025) and should not be used for trend comparison without adjusting for the partial year.
- Several neighbourhood and cuisine/borough groups have small sample sizes (under 100, sometimes under 30 inspections), making their averages unreliable for targeting. Any intervention should be validated against restaurant counts before resources are committed.
- Around 1 per cent of rows have missing geographic data at source. This does not materially affect borough or neighbourhood level analysis.

**Next steps:**

Three further questions would help zone in on what is actually happening inside the restaurants, and give a clearer idea of what to implement:

- **Repeat offenders**: which restaurants have been cited for the same critical violation multiple times across different inspections? A restaurant receiving the same critical violation repeatedly suggests the underlying problem is not being fixed. This would help the city prioritise which restaurants need escalated enforcement rather than routine re-inspection.
- **Seasonal violation patterns**: do certain violations spike in summer versus winter? Pest related violations such as 08A may worsen in warmer months, for example. This would help the city time targeted inspection campaigns seasonally rather than spreading them evenly across the year.
- **New restaurant risk**: do recently opened restaurants (identifiable by their earliest inspection date) perform worse than established ones? If so, the city could make food safety training a condition of licensing rather than waiting for the first inspection to reveal problems.

- Extend the neighbourhood level analysis into a fuller geographic targeting view.
