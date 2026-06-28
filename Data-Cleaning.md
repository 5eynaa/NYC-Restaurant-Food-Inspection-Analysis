# Data Cleaning Write-Up

DOHMH New York City Restaurant Inspection Results dataset. All cleaning carried out in MySQL.

---

## Table of Contents

1. [Step 1: Finding and deleting duplicate values](#step-1-finding-and-deleting-duplicate-values)
2. [Step 2a: Standardisation - Blanks (Grade and Score)](#step-2a-standardisation-blanks-grade-and-score)
3. [Step 2b: Standardisation - Violation Code and Violation Description](#step-2b-standardisation-violation-code-and-violation-description)
4. [Step 2c: Standardisation - Zipcode](#step-2c-standardisation-zipcode)
5. [Step 2d: Standardisation - Geolocation](#step-2d-standardisation-geolocation)
6. [Step 2e: Standardisation - Phone Number](#step-2e-standardisation-phone-number)
7. [Step 2f: Standardisation - Street Name](#step-2f-standardisation-street-name)
8. [Step 2g: Standardisation - Dates](#step-2f-standardisation-dates)

---

## Step 1: Finding and deleting duplicate values

A three-phase approach was used to identify and remove duplicate rows from the dataset. The logic works by numbering every row in the table, isolating the duplicates, and then deleting them from the original table.

**Phase 1:** assigns a row number to every record, partitioned across all 27 columns. Rows that are completely identical in every column receive the same partition group, with the first occurrence numbered 1 and any duplicates numbered 2, 3, and so on.

```sql
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY
            CAMIS, DBA, BORO, BUILDING, STREET, ZIPCODE, PHONE,
            `CUISINE DESCRIPTION`, `INSPECTION DATE`, ACTION,
            `VIOLATION CODE`, `VIOLATION DESCRIPTION`, `CRITICAL FLAG`,
            SCORE, GRADE, `GRADE DATE`, `RECORD DATE`, `INSPECTION TYPE`,
            Latitude, Longitude, `Community Board`, `Council District`,
            `Census Tract`, BIN, BBL, NTA, `Location Point1`
        ORDER BY CAMIS
    ) AS row_num
FROM nyc_restaraunt_inspections.nyc_inspections
```

**Phase 2:** filters the result of Phase 1 down to only the duplicate rows — anything with a row number greater than 1 — and returns three identifying columns to use as the deletion target.

```sql
SELECT CAMIS, `INSPECTION DATE`, `VIOLATION CODE`
FROM (...Phase 1...) AS row_table
WHERE row_num > 1
```

**Phase 3:** deletes any row from the main table where the combination of CAMIS, INSPECTION DATE and VIOLATION CODE matches a row returned by Phase 2.

```sql
DELETE FROM nyc_restaraunt_inspections.nyc_inspections
WHERE (CAMIS, `INSPECTION DATE`, `VIOLATION CODE`) IN (
    ...Phase 2...
)
```

---

## Step 2a: Standardisation — Blanks (Grade and Score)

#### Background

After removing duplicate rows and standardising violation descriptions, a full audit of blank and null values was conducted across all 27 columns of the dataset. The audit query used CASE statements to count both empty strings and NULL values for every column simultaneously, returning a single row with 27 counts giving a complete health check of the dataset in one query.

```sql
SELECT
    SUM(CASE WHEN CAMIS = '' OR CAMIS IS NULL THEN 1 ELSE 0 END) AS CAMIS_blanks,
    SUM(CASE WHEN DBA = '' OR DBA IS NULL THEN 1 ELSE 0 END) AS DBA_blanks,
    ... (all 27 columns) ...
FROM nyc_restaraunt_inspections.nyc_inspections;
```

(The full 27-column audit query is in `sql/01_cleaning.sql`.)

#### What the audit found

The blanks fell into four distinct categories:

**Category 1: No blanks (healthy columns)**

CAMIS, DBA, BORO, STREET, INSPECTION DATE, CRITICAL FLAG and RECORD DATE all returned zero blanks. These columns are complete and required no action.

**Category 2: Ghost records (01/01/1900 placeholder dates)**

3,699 rows had an inspection date of 01/01/1900, a classic system placeholder meaning no real date existed. These rows also had blank CUISINE DESCRIPTION, ACTION and INSPECTION TYPE; all three columns showed exactly 3,699 blanks, confirming they were all from the same rows.

Cross-referencing with the official data dictionary, which states the dataset contains only active restaurants with inspections from the last three years, these rows were confirmed as invalid ghost records with no analytical value.

**Action taken:** Deleted all 3,699 rows.

```sql
DELETE FROM nyc_restaraunt_inspections.nyc_inspections
WHERE `INSPECTION DATE` = '01/01/1900';
```

**Result:** Row count reduced from 288,876 to 285,177.

**Category 3: Expected blanks (correct by design)**

GRADE, SCORE and GRADE DATE had large blank counts: 148,032, 15,926 and 155,856 respectively. Before taking any action, an investigation query grouped the results by INSPECTION TYPE. This revealed that blank grades were directly linked to specific inspection types — not all inspection types generate an official grade, so these blanks were correct by design rather than errors.

**Action taken:** Rather than populating these blanks with invented values, empty strings were converted to proper NULL values. This preserves the meaning of the data while using the correct SQL standard for representing missing values.

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections SET GRADE = NULL WHERE GRADE = '';
UPDATE nyc_restaraunt_inspections.nyc_inspections SET SCORE = NULL WHERE SCORE = '';
UPDATE nyc_restaraunt_inspections.nyc_inspections SET `GRADE DATE` = NULL WHERE `GRADE DATE` = '';
```

**Category 4: Remaining blanks still to address**

| Column | Blank count | Notes |
| ----- | ----- | ----- |
| ZIPCODE | 2,896 | Important for neighbourhood analysis |
| BUILDING | 503 | Some addresses have no building number |
| PHONE | 6 | Minor, likely acceptable |
| Latitude / Longitude | 413 | Missing geographic coordinates |
| Community Board | 3,703 | Missing geographic data |
| Council District | 3,702 | Missing geographic data |
| Census Tract | 3,702 | Missing geographic data |
| BIN | 5,110 | Missing geographic data |
| BBL | 807 | Missing geographic data |
| NTA | 3,703 | Missing geographic data |
| Location Point1 | 285,177 | Entire column is blank |

---

## Step 2b: Standardisation — Violation Code and Violation Description

#### Background

During the data cleaning process of the dataset (288,876 rows after duplicate removal), it was discovered that the VIOLATION DESCRIPTION column contained multiple different versions of the same description for a single VIOLATION CODE.

#### The problem

A GROUP BY query revealed the issue. For example, violation code `08A` had two different descriptions:

- **"Establishment is not free of harborage or conditions conducive to rodents, insects or other pests"** — 24,103 occurrences
- **"Facility not vermin proof. Harborage or conditions conducive to attracting vermin to the premises and/or allowing vermin to exist"** — 3,195 occurrences

Both descriptions carry the same meaning but are worded differently. Left uncleaned, this would cause grouping and analysis problems — the same violation would appear as two separate categories in any report or visualisation.

#### The decision

The standardisation approach chosen was to keep the **most frequently occurring description** for each violation code. The reasoning was that the highest frequency version almost always represents the most recently standardised official wording, while lower frequency versions represent older, phased-out descriptions.

#### Step 1: Create a reference table

A reference table was created showing every unique combination of violation code and description along with how many times each appeared. This served as a full audit of the problem.

#### Step 2: Create a lookup table

A clean lookup table was created containing exactly one row per violation code paired with its most frequent description. ROW_NUMBER() was used to rank each description within its violation code group by frequency. Only the top-ranked description (rn = 1) was kept.

#### Step 3: Verify the lookup table

Before making any changes to the main table, a spot check was run on known violation codes ('02A', '02B', '08A', '04L', '04M') to confirm the lookup table had selected the correct description for each. Each code returned exactly one row with the highest frequency description confirmed.

#### Step 4: Run the UPDATE

The main table was updated by joining it to the lookup table and replacing every description with the standardised version.

#### Step 5: Verification

A verification query confirmed the standardisation was successful: **0 rows returned** — every violation code now has exactly one standardised description.

(Full queries for all five steps are in `sql/01_cleaning.sql`.)

---

## Step 2c: Standardisation — Zipcode

#### Background

As part of the ongoing blank value audit, the ZIPCODE column was identified as having a significant number of missing values. After removing the 3,699 ghost records, the updated blank count was investigated.

#### What the audit found

The blank zip codes were spread across all five boroughs with no single borough dominating:

| Borough | Blank ZIP codes |
| ----- | ----- |
| Manhattan | 1,446 |
| Queens | 610 |
| Bronx | 354 |
| Brooklyn | 325 |
| Staten Island | 96 |
| **Total** | **2,831** |

#### Investigation findings

A sample of 20 rows with missing zip codes was reviewed. The investigation found three distinct problems:

**Problem 1: Building number is zero**

Rows belonging to venues, stadiums and transport hubs such as Citi Field concession stands and Circle Line Manhattan had a building number of 0. These locations do not have traditional street numbers, making geocoding unreliable without additional research.

**Problem 2: Corrupted building numbers**

Several rows had building numbers that were clearly wrong, such as 106264, 40364040 and 15221524. These appear to be data entry errors at the source, possibly two fields that were merged together accidentally.

**Problem 3: Valid-looking building numbers**

Some rows had building numbers that appeared legitimate, such as 2057, 1155 and 2300, paired with recognisable NYC street names.

#### Action taken

Given that the affected rows represent only approximately 1% of the dataset, have missing coordinates, contain corrupted or zero building numbers, and that the primary analysis questions rely on BORO which is fully populated, all blank and zero zip code values were converted to NULL.

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections
SET ZIPCODE = NULL WHERE ZIPCODE = '' OR ZIPCODE = '0';
```

---

## Step 2d: Standardisation — Geolocation

#### Background

Following the ZIP code investigation, a refreshed blank audit was conducted on all remaining columns with missing values. The updated counts reflected the removal of the 3,699 ghost records and showed the following columns still required attention:

BUILDING (481), PHONE (6), Latitude (3,195), Longitude (3,195), Community Board (3,580), Council District (3,579), Census Tract (3,579), BIN (4,959), BBL (749), NTA (3,580) and Location Point1 (285,177).

#### Investigation approach

Before converting any blanks to NULL, a structured investigation was conducted to determine whether the geographic columns all belonged to the same incomplete restaurant records. The investigation query filtered on rows where Latitude was blank or zero and counted blanks across all other geographic columns within that same subset.

#### What the investigation found

The results revealed three distinct groups requiring different treatment:

**Group 1: Columns that blank out together completely**

Latitude, Longitude, Community Board and NTA all had exactly 3,195 blanks within the 3,195 rows with missing latitude. These were confirmed as the same incomplete restaurant records and were safe to convert to NULL together.

**Group 2: Columns with minor differences**

Council District and Census Tract had 3,187 blanks within the 3,195 rows; 8 rows short. This meant 8 rows had missing latitude but still had valid Council District and Census Tract values. These were converted to NULL separately to preserve the distinction.

**Group 3: BBL behaved differently**

BBL had only 364 blanks within the 3,195 rows with missing latitude. This meant 2,831 rows had missing coordinates but a valid BBL. The BBL investigation revealed that the 364 rows with missing BBL values were restaurants located in non-traditional locations including airport terminals, boardwalks and intersections. These locations do not exist in the NYC property tax system, which is what BBL references, meaning the missing values were completely legitimate and expected.

#### Actions taken

- **Group 1:** Latitude, Longitude, Community Board and NTA converted to NULL together.
- **Group 2:** Council District and Census Tract converted to NULL separately.
- **Group 3:** BBL converted to NULL after investigation.
- **BUILDING:** blank and N/A building numbers (non-traditional locations such as airports, boardwalks and intersections) converted to NULL.
- **Location Point1:** blank across every single one of the 285,177 rows, so the column was dropped entirely rather than converting to NULL.

#### Final verification

| Column | NULL count |
| ----- | ----- |
| Latitude | 3,195 |
| Longitude | 3,195 |
| Community Board | 3,580 |
| Council District | 3,579 |
| Census Tract | 3,579 |
| NTA | 3,580 |
| BBL | 749 |
| BUILDING | 484 |
| PHONE | 6 |

The BUILDING count came in at 484 rather than 481, accounted for by 3 additional rows where BUILDING was stored as N/A rather than a blank string, correctly caught by the update.

---

## Step 2e: Standardisation — Phone Number

#### Background

Following the geographic column audit, the PHONE column was identified as having 6 blank values. A targeted investigation was conducted before any action was taken.

#### Investigation findings

A GROUP BY query identified the unique restaurants behind the 6 blank rows. It returned only **one unique restaurant**: VAN LEEUWEN ICE CREAM at 224 Front Street, Manhattan (CAMIS `50088489`). The 6 blank rows all belonged to the same restaurant appearing across multiple inspection records.

#### Decision: convert to NULL rather than populate

A current phone number for this restaurant was found via a Google search. However, the decision was made to convert to NULL rather than populate the field because:

- The inspections span multiple years and the current phone number found online cannot be verified as accurate for the period covered by the inspections.
- The PHONE column has no analytical value for any of the four analysis questions.
- Populating a value that cannot be verified from the original data source introduces uncertainty; NULL is always more honest than an unverifiable value.
- Consistency: every other missing value throughout the cleaning process was handled by converting to NULL.

#### Standardisation: formatting phone numbers with dashes

After handling the blank values, a standardisation step was applied. The raw phone numbers were stored as unformatted 10-digit strings such as `2125290539`. These were reformatted to the standard US format with dashes such as `212-529-0539`, using SUBSTRING to extract each segment and CONCAT to join them:

- Characters 1 to 3
- Dash
- Characters 4 to 6
- Dash
- Characters 7 to 10

A preview query was run first, then the UPDATE was applied with a `WHERE PHONE IS NOT NULL` clause to protect the NULL value set for Van Leeuwen Ice Cream from being processed by the formatting update.

---

## Street Name Standardisation

#### Issue 3: Typos and misspellings

A suffix analysis query revealed genuine spelling errors in the dataset. The following typos were identified and corrected:

| Original | Corrected |
| ----- | ----- |
| SREET | STREET |
| STRRET | STREET |
| BLVE | BOULEVARD |
| BOULEVA | BOULEVARD |
| ST. | STREET |
| EXPAY | EXPRESSWAY |
| AIRPOR | AIRPORT |
| AIRPORAT | AIRPORT |
| ARPT | AIRPORT |
| B'WAY | BROADWAY |
| AMER | AMERICAS |
| EXT | Investigated separately |
| PK | Investigated separately |

**EXT and PK investigation:**

EXT was flagged as a potential risk before inclusion in the bulk update. Investigation revealed that EXT appeared inside legitimate words such as EXTERIOR STREET and EXTRA PLACE; a bulk replacement would have corrupted these to EXTENSIONRIOR STREET and EXTENSIONRA PLACE. Only 2 rows genuinely needed fixing and these were handled with a targeted manual update:

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections
SET STREET = 'FLATBUSH AVENUE EXTENSION'
WHERE STREET = 'FLATBUSH AVENUE EXT';
```

PK similarly appeared in only 12 rows across two street names: MORRIS PK AVENUE and EDERLE TERRACE FLUSHING MEADOW CORONA PK. Both were confirmed as PARK abbreviations and fixed with targeted manual updates.

**AVENUE OF TH AMER:**

During the typo fix, the value `AVENUE OF TH AMER` was updated to `AVENUE OF THE AMERICAS`. This was based on geographical knowledge of New York City, where Avenue of the Americas is a well-known Manhattan avenue also known as 6th Avenue. This change highlighted an important data cleaning principle: geographical assumptions should always be verified against other columns in the dataset (such as BORO and ZIPCODE) rather than applied on the basis of assumed knowledge alone. Avenue of the Americas runs through Manhattan with ZIP codes in the 10001 to 10036 range, so cross-referencing those columns confirms the change.

**How many rows were affected:** 120 across all typo fixes. Verification: count of rows containing original typo values returned 0.

#### Issue 4: Compass direction abbreviations

Streets beginning with a single compass letter such as `S CONDUIT AVENUE`, `N CONDUIT AVENUE`, `E FORDHAM ROAD` and `W 42ND STREET` were investigated.

Before making any changes, a full investigation was conducted. A query returned all streets starting with N, S, E or W followed by a space, and the results were reviewed carefully:

- All W entries were confirmed as West: Manhattan's grid system divides streets into East and West from 5th Avenue.
- All E entries were confirmed as East for the same reason.
- N CONDUIT AVENUE was confirmed as North Conduit Avenue in Queens.
- S CONDUIT AVENUE, S 8TH AVENUE, S 5TH STREET and others were confirmed as South: Brooklyn's Williamsburg neighbourhood uses North and South designations for some streets.

**Key distinction established:** single compass letters at the START of a street name are compass direction abbreviations. Single letters at the END of a street name, such as AVENUE S and AVENUE N, are genuine street names from Brooklyn's lettered avenue grid and must not be changed.

**Action taken:** the `^` anchor was used in REGEXP_REPLACE to ensure only letters at the very start of the street name were replaced:

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections
SET STREET = REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
        STREET,
    '^N ', 'NORTH '),
    '^S ', 'SOUTH '),
    '^E ', 'EAST '),
    '^W ', 'WEST ')
WHERE STREET REGEXP '^(N|S|E|W) ';
```

Verification: count of rows still starting with a single compass letter returned 0.

---

## Step 2f: Standardisation — Dates

#### Background

Three columns (INSPECTION DATE, GRADE DATE and RECORD DATE) were identified as being stored as text strings rather than proper date values. While the dates looked correct visually, they were technically just text in the format `MM/DD/YYYY`. This meant MySQL could not perform any date-based calculations or comparisons on them, which would have been a significant limitation for the third analysis question about how violations vary over time.

#### Verification before converting

Before making any changes, the columns were checked to confirm all dates consistently followed the same `MM/DD/YYYY` format, no unexpected values or placeholder dates remained, NULL values in GRADE DATE were displaying correctly, and RECORD DATE was consistent across all rows showing `09/18/2025` as the dataset extract date.

#### The conversion process

**Step 1: Preview the conversion**

`STR_TO_DATE` was used to translate the text dates into proper MySQL date format. A preview was run first on 10 rows.

**Step 2: Update all three columns**

Once the preview was confirmed, the UPDATE was applied to all rows using `STR_TO_DATE(column, '%m/%d/%Y')`.

**Step 3: Alter the column data types**

Converting the values alone was not sufficient; the columns were still defined as text in the table structure. The data types were altered to DATE to make the change permanent and recognised by MySQL:

```sql
ALTER TABLE nyc_restaraunt_inspections.nyc_inspections
MODIFY COLUMN `INSPECTION DATE` DATE,
MODIFY COLUMN `GRADE DATE` DATE,
MODIFY COLUMN `RECORD DATE` DATE;
```

All three columns now display in MySQL standard DATE format `YYYY-MM-DD`. NULL values in GRADE DATE are preserved correctly.

#### What STR_TO_DATE does

STR_TO_DATE acts as a translator. The dates were stored as text strings that MySQL could not interpret as dates. It reads the text and converts it into a proper date using a format string to understand the structure: `%m` two-digit month, `%d` two-digit day, `%Y` four-digit year, `/` the separator. Without this conversion, MySQL would treat `08/24/2022` as plain text, meaning date arithmetic, date filtering and time series analysis would all either fail or produce incorrect results.
