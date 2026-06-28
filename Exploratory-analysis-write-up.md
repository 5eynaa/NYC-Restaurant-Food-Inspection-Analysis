# Exploratory Analysis Write-Up

The four analysis questions, answered in MySQL. Full queries are in `sql/02_analysis.sql`.

---

## Table of Contents

1. [Question 1: Which violations are most common, and where do they occur most frequently?](#question-1-which-violations-are-most-common-and-where-do-they-occur-most-frequently)
2. [Question 2: Which cuisines and neighbourhoods have the lowest food safety performance?](#question-2-which-cuisines-and-neighbourhoods-have-the-lowest-food-safety-performance)
3. [Question 3: How do restaurant grades and violations vary across boroughs and over time?](#question-3-how-do-restaurant-grades-and-violations-vary-across-boroughs-and-over-time)
4. [Question 4: Where should the city focus inspections, policies, or education to improve food safety?](#question-4-where-should-the-city-focus-inspections-policies-or-education-to-improve-food-safety)

---

## Question 1: Which violations are most common, and where do they occur most frequently?

#### Approach

The question was broken into two components: which violations occur most frequently citywide, and how that picture changes when broken down by borough. The analysis was built in four stages, moving from a broad citywide overview to a ranked, severity-aware borough breakdown.

#### Findings

**Stage 1: Citywide overview**

Violations were counted across the entire cleaned dataset, filtering out NULL and blank violation codes (rows where no violation was recorded). The most common violation citywide was **10F** (non-food contact surface issues) with **40,037 occurrences**, followed by **08A** (conditions conducive to pests) with **27,298 occurrences**.

**Stage 2: Borough breakdown**

The query was expanded to include BORO. This returned every violation type for every borough but produced too many rows to read directly, so the results were narrowed in Stage 3.

**Stage 3: Top 5 per borough**

A CTE with `ROW_NUMBER()` partitioned by borough was used to rank violations within each borough separately, so each of the five boroughs received its own top 5 ranking rather than one combined list weighted towards Manhattan's larger restaurant volume. **10F and 08A ranked 1st and 2nd in every single borough without exception**, indicating these are systemic citywide problems rather than localised ones.

**Stage 4: Adding severity context**

CRITICAL FLAG was added to the top 5 query. The two most frequent violations (10F and 08A) are both classified as Not Critical. However, violations ranked 3rd through 5th in most boroughs are typically Critical, including 06D (food contact surface not sanitised), 02G (cold food held above temperature) and 04L (evidence of mice). Frequency and severity do not align: the most cited violations are structural, while the most dangerous ones sit just below them.

#### Findings summary

| Finding | Detail |
| ----- | ----- |
| Most common violation citywide | 10F, non-food contact surface issues, 40,037 occurrences, Not Critical |
| Second most common citywide | 08A, harborage conditions for pests, 27,298 occurrences, Not Critical |
| Top 2 pattern | 10F and 08A ranked 1st and 2nd in every borough without exception |
| Borough with highest raw counts | Manhattan, driven by restaurant density |
| Notable borough difference | Queens: 06C ranks 3rd instead of 06D as in all other boroughs |
| Critical vs Not Critical pattern | Most frequent violations are Not Critical, but Critical violations consistently appear in ranks 3 to 5 |

Across all five boroughs the most common violation is non-food contact surface issues (10F) followed by harborage conditions conducive to pests (08A), both classified as Not Critical. Critical violations including improper food temperature control and evidence of mice consistently appear in the top 5 across every borough.

---

## Question 2: Which cuisines and neighbourhoods have the lowest food safety performance?

#### Approach

Food safety performance was measured using three complementary metrics rather than one, to avoid a misleading picture from any single figure:

- **Average SCORE:** the primary measure of overall inspection performance (higher = worse in NYC's system)
- **Critical violation percentage:** the proportion of inspections where at least one Critical violation was cited
- **Grade distribution:** the breakdown of A, B, C, N, Z and P grades per cuisine and borough

`COUNT(SCORE)` was used rather than `COUNT(*)` throughout, so that the sample size behind each average reflects only scored inspections rather than all rows. `COUNT(GRADE)` was used as the denominator for all grade percentages rather than `COUNT(*)`, because GRADE has a large number of NULL values by design. Using `COUNT(*)` would have artificially deflated all grade percentages by including inspections that were never eligible for a grade.

The raw `CUISINE DESCRIPTION` column contains a long tail of very specific labels. Plotted directly, these produced a heatmap with too many sparse rows to read. A `CASE WHEN` inside a CTE was used to group the individual labels into broader categories (South Asian, African, East Asian, Latin American, Mediterranean, European and so on) before averaging score per group and borough. The two catch-all labels ('Not Listed/Not Applicable' and 'Other') were excluded. The full grouping query is in `sql/02_analysis.sql`.

#### Grade legend

| Grade | Meaning |
| ----- | ----- |
| A | Passing |
| B | Needs improvement |
| C | Poor performance |
| N | Not yet graded |
| Z | Grade pending, under contest |
| P | Grade pending on re-opening following closure |

N, Z and P are administrative statuses rather than performance grades and should be treated separately when interpreting grade distribution results.

#### Findings

**Worst performing cuisine groups by average score (grouped, with meaningful sample sizes):**

| Cuisine group | Borough | Average score | Score count |
| ----- | ----- | ----- | ----- |
| African | Manhattan | 38.63 | 574 |
| South Asian | Queens | 37.11 | 2,415 |
| South Asian | Brooklyn | 34.39 | 1,488 |
| African | Bronx | 34.15 | 434 |
| South Asian | Manhattan | 32.74 | 2,045 |
| Chinese | Manhattan | 31.41 | 7,401 |
| Caribbean | Manhattan | 30.84 | 708 |
| Chinese | Queens | 30.77 | 9,399 |
| South Asian | Bronx | 29.75 | 293 |

**South Asian** is the standout poor performer, appearing in four of the five boroughs and peaking in Queens (37.1 across 2,415 inspections). **African** produces the single worst cuisine/borough score in the dataset in Manhattan (38.6 across 574 inspections), and is also high in the Bronx. Both groups rest on far larger samples than the individual cuisine labels did before grouping, making the finding more reliable.

**Best performing cuisine groups:** high-volume groups such as American, Beverages & Snacks and Sandwiches/Soups/Salads consistently sit at the lower end of the average score ranking (lower = better), largely driven by chains with standardised processes and high inspection volumes. American in the Bronx, for example, averages 19.94 across 4,064 inspections.

**Grade distribution patterns:**

- Cuisine groups with the highest average scores tend to have lower grade A percentages.
- Groups with lower average scores tend to have higher grade A percentages; American Manhattan has 75.99% A grades from a very large inspection base.
- Critical violation percentages are consistently high across all cuisines, ranging from roughly 40% to 65%, suggesting critical violations are widespread rather than isolated to specific cuisine types.

#### Sample size caveat

Before grouping, several individual cuisine/borough combinations had very low inspection counts (for example Chinese/Cuban Brooklyn with 42, Southwestern Brooklyn with 21, Russian Staten Island with 7), making their averages unreliable. Grouping the cuisines addressed this by pooling enough inspections to be dependable. Where a grouped category still has a small count in a given borough (for example African in Queens with 37 inspections), that figure is treated with caution.

---

## Question 3: How do restaurant grades and violations vary across boroughs and over time?

#### Approach

Question 3 had two distinct parts requiring separate queries: how grades vary by borough and over time (Part A), and how violations vary by borough and over time (Part B).

`INSPECTION DATE` was chosen as the primary time dimension. It is the date the inspector physically visited the restaurant and observed violations, making it the most meaningful date for trend analysis. GRADE DATE has large numbers of NULLs since many inspection types never generate a grade, and RECORD DATE is the dataset extraction date and therefore the same value across all rows.

Year-level granularity was chosen over month or day level. The dataset covers approximately three years of active inspections, giving a clean 2022 to 2025 window sufficient to identify trends without excessive noise.

#### Part A: Grades by borough and over time

The query grouped by year, borough and grade, counting how many times each grade appeared per combination. Rows with NULL or blank GRADE values were excluded, since many inspection types are never eligible for a grade by design and including them would inflate the denominator. Results were filtered to 2022 onwards; earlier inspection dates exist in the dataset but represent a small, unreliable historical sample.

##### Grade legend

| Grade | Meaning |
| ----- | ----- |
| A | Passing |
| B | Needs improvement |
| C | Poor performance |
| N | Not yet graded |
| Z | Grade pending, under contest |
| P | Grade pending on re-opening following closure |

##### Key findings: Part A

Grade A counts grew year on year across all boroughs from 2022 to 2024, suggesting a genuine improvement in food safety performance across the city:

| Borough | 2022 A | 2023 A | 2024 A | 2025 A |
| ----- | ----- | ----- | ----- | ----- |
| Manhattan | 7,478 | 9,385 | 11,126 | 7,852 |
| Brooklyn | 5,206 | 6,037 | 7,859 | 4,861 |
| Queens | 4,131 | 5,240 | 6,662 | 4,956 |
| Bronx | 1,468 | 2,180 | 2,822 | 2,093 |
| Staten Island | 877 | 1,062 | 1,096 | 529 |

The 2025 figures are lower across all boroughs because the dataset was extracted in September 2025 and covers only approximately three quarters of the year. This should be noted as a caveat whenever 2025 figures are presented.

Manhattan consistently has the highest raw grade counts across all categories, which reflects restaurant density rather than better or worse performance. Raw counts alone are not suitable for borough comparison; rates and percentages are more appropriate and will be addressed in Power BI.

N and Z grades spike sharply in 2025, particularly in Manhattan where N reached 1,836 and Z reached 2,000, both significantly higher than prior years even accounting for the partial year. This is a notable finding that warrants further investigation.

#### Part B: Violation frequency by borough and over time

The query grouped by year, borough and violation code, counting how many times each violation was cited per combination. The `GRADE IS NOT NULL` filter used in Part A was deliberately removed here, since violation records exist on inspections that never generate a grade. Keeping the filter would have caused a significant undercount by excluding all ungraded inspections from the violation totals.

##### Key findings: Part B

Violation 10F is the single most cited violation in every borough every year by a significant margin, and it grew substantially year on year up to 2024:

| Borough | 2022 | 2023 | 2024 | 2025 |
| ----- | ----- | ----- | ----- | ----- |
| Bronx | 597 | 1,009 | 1,341 | 1,004 |
| Brooklyn | 2,025 | 2,462 | 3,127 | 2,167 |
| Manhattan | 2,952 | 3,671 | 4,481 | 3,556 |
| Queens | 1,604 | 2,128 | 2,951 | 2,397 |
| Staten Island | 391 | 463 | 500 | 240 |

The 2025 figures are lower due to the partial year, consistent with the grade count pattern in Part A.

Violation 08A is consistently the second most cited violation citywide and also grows year on year up to 2024 across all boroughs, confirming the findings from Question 1.

The same top violations dominate in every borough and every year: 10F, 08A, 06D, 02G, 10B, 06C, 02B, 04L and 04N consistently appear in the top ten across all boroughs, suggesting the issues are systemic and city-wide rather than borough-specific.

Manhattan has the highest raw violation counts in every category, reflecting restaurant density. Staten Island consistently has the lowest counts for the same reason.

---

## Question 4: Where should the city focus inspections, policies, or education to improve food safety?

#### Approach

Question 4 is a synthesis question. It draws on the findings from Questions 1, 2 and 3, combined with a neighbourhood (NTA) level query, to identify where food safety risk concentrates geographically. The aim is to pinpoint the areas and violations that matter most. Deciding the precise mechanism to address them is the natural follow-on step rather than something this analysis prescribes.

A query was built grouping by NTA and BORO, calculating average score, score count and critical violation percentage. This extended the Question 2 cuisine-level analysis down to neighbourhood level. NULL NTA values were filtered out as they represent inspections where geographic data was not recorded.

#### Where to focus inspections

The worst performing neighbourhoods by average score with meaningful sample sizes are listed below by borough:

**Bronx:** Allerton-Pelham Gardens (BX31, avg 28.5, 452 inspections), Woodlawn-Wakefield (BX62, avg 27.0, 834 inspections), Fordham South (BX40, avg 26.9, 728 inspections) and Longwood (BX33, avg 26.2, 469 inspections).

**Brooklyn:** Williamsburg (BK72, avg 34.0, 149 inspections, treat with caution), Kensington-Ocean Parkway (BK41, avg 33.9, 644 inspections) and Borough Park (BK88, avg 31.1, 1,252 inspections).

**Queens:** Elmhurst-Maspeth (QN50, avg 32.9, 1,075 inspections), Glen Oaks-Floral Park-New Hyde Park (QN44, avg 31.2, 540 inspections) and Flushing (QN22, avg 30.7, 6,089 inspections). Flushing in particular represents a major concentration of sustained poor performance.

**Manhattan:** Chinatown (MN27, avg 27.4, 6,092 inspections) and Morningside Heights (MN09, avg 27.4, 1,647 inspections).

**Staten Island:** Grymes Hill-Clifton-Fox Hills (SI08, avg 26.3) and Port Richmond (SI28, avg 25.4), though Staten Island's borough-level averages are lower than other boroughs overall, suggesting comparatively better performance.

The clearest signal is to concentrate increased inspection frequency and proactive enforcement in the Bronx (particularly Allerton-Pelham Gardens, Woodlawn-Wakefield and Fordham South) and Queens (particularly Elmhurst-Maspeth and Flushing), where high average scores and critical violation rates are sustained across large restaurant populations.

#### Which violations to address

From Question 3, violation 10F is growing year on year across every borough, reaching over 4,400 citations in Manhattan in 2024 alone. Violation 08A is the second most common citywide and equally persistent.

Both are structural and infrastructure-related rather than one-off behavioural lapses. A restaurant cited for 10F repeatedly is likely dealing with ageing equipment or building maintenance issues that go beyond individual food handler training, which is why repeatedly citing the same violation at the next inspection changes little. The contribution of this analysis is to identify exactly which violations dominate and where they cluster. Finding the right way to tackle them in those areas is the next step.

#### Where the cuisine risk concentrates

From Question 2, the South Asian cuisine carries the highest average scores across Queens, Brooklyn, Manhattan and the Bronx, and the African group is the single worst cuisine/borough combination in the dataset (Manhattan, average 38.6). These are the groups and areas where targeted support would have the most effect. The neighbourhoods where these cuisines are densest, such as Flushing and Elmhurst in Queens and parts of the Bronx, are logical starting points.

#### Key summary

**Where to inspect:** increase frequency and enforcement intensity in the Bronx (Allerton-Pelham Gardens, Woodlawn-Wakefield, Fordham South) and Queens (Elmhurst-Maspeth, Flushing), which show the highest sustained average scores and critical violation rates with large restaurant populations.

**Which violations to address:** focus on 10F and 08A, the two dominant and growing violations citywide, and find a route to tackle them directly in the worst affected areas rather than continuing to cite them repeatedly.

**Where the cuisine risk sits:** the South Asian and African cuisine groups in Queens, Brooklyn, Manhattan and the Bronx, where average scores are consistently highest.
