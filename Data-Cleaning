# Data Cleaning Write-Up

DOHMH New York City Restaurant Inspection Results dataset. All cleaning carried out in MySQL.

---

## Issue: uploading the data

**The problem**

A large CSV file (DOHMH New York City Restaurant Inspection Results) was imported into MySQL Workbench using the Table Data Import Wizard. The CSV contained 288,888 rows of data. After running the import, only 31 rows were successfully imported.

**First diagnosis and attempted fix**

Looking at the import error logs, the errors pointed to incorrect data types being auto-assigned by the wizard during the import configuration step. Specifically:

- `PHONE` was set to `int` but phone numbers exceed MySQL's INT maximum value of 2,147,483,647
- `BUILDING` was set to `int` but contained blank and non-numeric values
- `ZIPCODE` was set to `int` but contained blank values
- `BBL` was set to `int` but values exceeded INT range
- `Longitude` was set to `json` instead of `double`

These data types were corrected in the import wizard and the import attempted again. This improved the result slightly but still only returned 203 rows — far short of the expected 288,888.

**Root cause**

The MySQL Workbench Table Data Import Wizard has a known limitation with large files. It is not designed to reliably handle CSVs with hundreds of thousands of rows and was silently failing after a small number of records regardless of the data type corrections.

**The fix that worked**

`LOAD DATA INFILE` was used instead, which is MySQL's native bulk import command and is built specifically for handling large files efficiently. The steps were:

1. Ran `SHOW VARIABLES LIKE 'secure_file_priv'` to identify the directory MySQL is permitted to read files from (`C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\`)
2. Moved the CSV file into that directory
3. Truncated the partially imported table to clear the 203 incomplete rows
4. Ran the `LOAD DATA INFILE` command pointing to the new file location

Result: all 288,888 rows imported with 0 skipped and 0 warnings.

**Key takeaway**

For any CSV file with more than a few thousand rows, `LOAD DATA INFILE` is the correct and reliable method. The Table Data Import Wizard is only suitable for small datasets.

---

## Step 1: Finding and deleting duplicate values

**Layer 1:** This goes through every single row in the table and assigns a number to it. Using a photocopier analogy:

- Original paper gets number **1**
- Photocopy gets number **2**

It partitions across all 27 columns, meaning it only gives the same number sequence to rows that are completely identical in every column.

```sql
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY
            CAMIS, DBA, BORO, ...all 27 columns...
        ORDER BY CAMIS
    ) AS row_num
FROM nyc_restaraunt_inspections.nyc_inspections
```

**Layer 2:** This takes the result from Layer 1 and filters it down to only the photocopies — anything with row_num greater than 1. It then pulls out just three identifying columns from those rows:

- CAMIS
- INSPECTION DATE
- VIOLATION CODE

Think of this as creating a **list of photocopies to throw away**.

```sql
SELECT CAMIS, `INSPECTION DATE`, `VIOLATION CODE`
FROM (...layer 1...) AS row_table
WHERE row_num > 1
```

**Layer 3:** This is the action layer. It says: **"Go into the table and delete any row where the combination of CAMIS, INSPECTION DATE and VIOLATION CODE matches something on our list of photocopies to throw away."**

```sql
DELETE FROM nyc_restaraunt_inspections.nyc_inspections
WHERE (CAMIS, `INSPECTION DATE`, `VIOLATION CODE`) IN (
    ...layer 2...
)
```

### The full picture simply

**Step 1** — Number every row, giving duplicates a higher number
**Step 2** — Make a list of the rows that got a number higher than 1
**Step 3** — Delete anything on that list from the real table

---

## Step 2a: Standardisation Blanks (`Grade` and `Score`)

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

**Category 1 — No blanks (healthy columns)**

CAMIS, DBA, BORO, STREET, INSPECTION DATE, CRITICAL FLAG and RECORD DATE all returned zero blanks. These columns are complete and required no action.

**Category 2 — Ghost records (01/01/1900 placeholder dates)**

3,699 rows had an inspection date of 01/01/1900, a classic system placeholder meaning no real date existed. These rows also had blank CUISINE DESCRIPTION, ACTION and INSPECTION TYPE — all three columns showing exactly 3,699 blanks, confirming they were all from the same rows.

Cross referencing with the official data dictionary, which states the dataset contains only active restaurants with inspections from the last three years, these rows were confirmed as invalid ghost records with no analytical value.

**Action taken:** Deleted all 3,699 rows

```sql
DELETE FROM nyc_restaraunt_inspections.nyc_inspections
WHERE `INSPECTION DATE` = '01/01/1900';
```

**Result:** Row count reduced from 288,876 to 285,177

**Category 3 — Expected blanks (correct by design)**

GRADE, SCORE and GRADE DATE had large blank counts — 148,032, 15,926 and 155,856 respectively. Before taking any action, an investigation query grouped by INSPECTION TYPE.

This revealed that blank grades were directly linked to specific inspection types. In New York City's restaurant inspection system not all inspection types generate an official grade. For example administrative inspections check permit compliance and signage posting — they do not assess food safety and never produce a grade. Similarly cycle initial inspections only produce an immediate grade if the restaurant scores 13 or below. Higher scores result in a re-inspection first, meaning the grade column is intentionally blank on those rows.

**Key lesson:** A blank value is not always a data quality problem. Understanding the business context behind the data is essential before deciding how to handle blanks.

**Action taken:** Rather than populating these blanks with invented values which would be incorrect, empty strings were converted to proper NULL values. This preserves the meaning of the data while using the correct SQL standard for representing missing values.

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections SET GRADE = NULL WHERE GRADE = '';
UPDATE nyc_restaraunt_inspections.nyc_inspections SET SCORE = NULL WHERE SCORE = '';
UPDATE nyc_restaraunt_inspections.nyc_inspections SET `GRADE DATE` = NULL WHERE `GRADE DATE` = '';
```

**Important distinction:** Converting empty strings to NULL does not add or change any data. It simply changes how the absence of data is represented, making it cleaner and more consistent for analysis.

**Category 4 — Remaining blanks still to address**

| Column | Blank count | Notes |
| ----- | ----- | ----- |
| ZIPCODE | 2,896 | Important for neighbourhood analysis |
| BUILDING | 503 | Some addresses have no building number |
| PHONE | 6 | Minor — likely acceptable |
| Latitude / Longitude | 413 | Missing geographic coordinates |
| Community Board | 3,703 | Missing geographic data |
| Council District | 3,702 | Missing geographic data |
| Census Tract | 3,702 | Missing geographic data |
| BIN | 5,110 | Missing geographic data |
| BBL | 807 | Missing geographic data |
| NTA | 3,703 | Missing geographic data |
| Location Point1 | 285,177 | Entire column is blank |

#### Key lessons for future projects

1. **Always audit first** — run a full blank count across all columns before touching anything. Never assume where the blanks are.
2. **Understand your data dictionary** — the official documentation for this dataset was essential in confirming that the 01/01/1900 rows were invalid and that blank grades were expected by design.
3. **Blank does not always mean broken** — context matters enormously. A blank grade on an administrative inspection is correct. A blank grade on a re-inspection is suspicious. The same blank value can mean two completely different things depending on context.
4. **Empty string vs NULL** — in MySQL an empty string and NULL both represent missing data but NULL is the proper standard. Always convert empty strings to NULL for consistency, especially in columns that will be used in calculations or aggregations.
5. **Never populate values you cannot verify** — it is better to leave a value as NULL than to fill it with something that might be wrong. Incorrect data is more dangerous than missing data.
6. **Investigate before deleting** — the 01/01/1900 rows were only deleted after confirming through multiple queries and the data dictionary that they had no analytical value. Always build the case before removing data.

---

## Step 2b: Standardisation (`VIOLATION CODE` and `VIOLATION DESCRIPTION`)

#### Background

During the data cleaning process of the dataset (288,876 rows after duplicate removal), it was discovered that the VIOLATION DESCRIPTION column contained multiple different versions of the same description for a single VIOLATION CODE.

This happened for two reasons:

- New York City health inspectors updated the official wording of violation descriptions over time, meaning older inspections had older wording and newer inspections had newer wording
- Some descriptions had minor cosmetic differences such as extra spaces within the text

#### The problem

A GROUP BY query revealed the issue. For example violation code `08A` had two different descriptions:

- **"Establishment is not free of harborage or conditions conducive to rodents, insects or other pests"** — 24,103 occurrences
- **"Facility not vermin proof. Harborage or conditions conducive to attracting vermin to the premises and/or allowing vermin to exist"** — 3,195 occurrences

Both descriptions mean the same thing but are worded differently. Left uncleaned this would cause grouping and analysis problems — the same violation would appear as two separate categories in any report or visualisation.

#### The decision

The standardisation approach chosen was to keep the **most frequently occurring description** for each violation code. The reasoning was that the highest frequency version almost always represents the most recently standardised official wording. Lower frequency versions represent older phased out descriptions.

#### Step 1 — Create a reference table

A reference table was created showing every unique combination of violation code and description along with how many times each appeared. This served as a full audit of the problem.

#### Step 2 — Create a lookup table

A clean lookup table was created containing exactly one row per violation code paired with its most frequent description. ROW_NUMBER() was used to rank each description within its violation code group by frequency. Only the top ranked description (rn = 1) was kept.

#### Step 3 — Verify the lookup table

Before making any changes to the main table, a spot check was run on known violation codes ('02A', '02B', '08A', '04L', '04M') to confirm the lookup table had selected the correct description for each. Each code returned exactly one row with the highest frequency description confirmed.

#### Step 4 — Run the UPDATE

The main table was updated by joining it to the lookup table and replacing every description with the standardised version.

Note: A timeout error (Error 2013) was encountered on the first attempt due to the size of the dataset. This was resolved by increasing the MySQL session timeout settings and reconnecting before running the query again.

#### Step 5 — Verification

A verification query confirmed the standardisation was successful: **0 rows returned** — every violation code now has exactly one standardised description.

(Full queries for all five steps are in `sql/01_cleaning.sql`.)

#### Key lessons for future projects

1. **Always investigate before standardising** — run a GROUP BY query first to understand how many versions exist and how common each one is before deciding on an approach.
2. **Create a lookup table rather than hardcoding values** — this approach scales to any number of violation codes automatically without needing to write individual CASE statements.
3. **Verify before updating** — always check the lookup table against known values before running the UPDATE on the full dataset.
4. **Exclude blank rows** — always add a WHERE clause to exclude rows where the column being standardised is empty, to avoid accidentally modifying clean inspection records.
5. **Large updates may timeout** — for datasets with hundreds of thousands of rows, increase the MySQL session timeout before running bulk UPDATE statements, or split the update into batches by filtering on subsets of the data.

---

## Step 2c: Standardisation (`ZIPCODE`)

#### Background

As part of the ongoing blank value audit, the ZIPCODE column was identified as having a significant number of missing values. After removing the 3,699 ghost records the updated blank count was investigated.

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

**Problem 1 — Building number is zero**

Rows belonging to venues, stadiums and transport hubs such as Citi Field concession stands and Circle Line Manhattan had a building number of 0. These locations do not have traditional street numbers making geocoding unreliable without additional research.

**Problem 2 — Corrupted building numbers**

Several rows had building numbers that were clearly wrong such as 106264, 40364040 and 15221524. No NYC building has a 6 or 8 digit building number. These appear to be data entry errors at the source, possibly two fields that were merged together accidentally.

**Problem 3 — Valid looking building numbers**

Some rows had building numbers that appeared legitimate such as 2057, 1155 and 2300 paired with recognisable NYC street names.

Importantly all rows with missing zip codes also had missing latitude and longitude values stored as 0 rather than NULL, confirming these are inherently incomplete records at the data source level.

#### Action taken

Given that the affected rows represent only approximately 1% of the dataset, have missing coordinates, contain corrupted or zero building numbers, and that the primary analysis questions rely on BORO which is fully populated, all blank and zero zip code values were converted to NULL:

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections
SET ZIPCODE = NULL WHERE ZIPCODE = '' OR ZIPCODE = '0';
```

#### Key lessons for future projects

1. **Zero is not always a valid value** — in this dataset missing coordinates were stored as 0 rather than NULL. Always check for placeholder numeric values like 0 as well as empty strings and NULLs when auditing blanks.
2. **Understand why data is missing** — the missing zip codes were spread across all boroughs and linked to venues without traditional addresses. This is a source data quality issue, not something introduced during import.
3. **1% missing data is generally acceptable** — for a dataset of this size 2,831 missing zip codes will not materially affect borough or neighbourhood level analysis. It is better to acknowledge the limitation than to fill in values that cannot be verified.

---

## Step 2d: Standardisation (`Geolocation`)

#### Background

Following the ZIP code investigation, a refreshed blank audit was conducted on all remaining columns with missing values. The updated counts reflected the removal of the 3,699 ghost records and showed the following columns still required attention:

BUILDING (481), PHONE (6), Latitude (3,195), Longitude (3,195), Community Board (3,580), Council District (3,579), Census Tract (3,579), BIN (4,959), BBL (749), NTA (3,580) and Location Point1 (285,177).

#### Investigation approach

Before converting any blanks to NULL a structured investigation was conducted to determine whether the geographic columns all belonged to the same incomplete restaurant records. The investigation query filtered on rows where Latitude was blank or zero and counted blanks across all other geographic columns within that same subset.

#### What the investigation found

The results revealed three distinct groups requiring different treatment:

**Group 1 — Columns that blank out together completely**

Latitude, Longitude, Community Board and NTA all had exactly 3,195 blanks within the 3,195 rows with missing latitude. These confirmed as the same incomplete restaurant records and were safe to convert to NULL together.

**Group 2 — Columns with minor differences**

Council District and Census Tract had 3,187 blanks within the 3,195 rows — 8 rows short. This meant 8 rows had missing latitude but still had valid Council District and Census Tract values. These were converted to NULL separately to preserve the distinction.

**Group 3 — BBL behaved differently**

BBL had only 364 blanks within the 3,195 rows with missing latitude. This meant 2,831 rows had missing coordinates but a valid BBL. The BBL investigation revealed that the 364 rows with missing BBL values were restaurants located in non-traditional locations including airport terminals, boardwalks and intersections. These locations do not exist in the NYC property tax system which is what BBL references, meaning the missing values were completely legitimate and expected.

#### Actions taken

- **Group 1** — Latitude, Longitude, Community Board and NTA converted to NULL together.
- **Group 2** — Council District and Census Tract converted to NULL separately.
- **Group 3** — BBL converted to NULL after investigation.
- **BUILDING** — blank and N/A building numbers (non-traditional locations such as airports, boardwalks and intersections) converted to NULL.
- **Location Point1** — blank across every single one of the 285,177 rows, so the column was dropped entirely rather than converting to NULL.

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

The BUILDING count came in at 484 rather than 481 — accounted for by 3 additional rows where BUILDING was stored as N/A rather than a blank string, correctly caught by the update.

#### Key lessons for future projects

1. **Always investigate before grouping columns together** — columns with similar blank counts are not necessarily from the same rows. The BBL investigation proved this.
2. **Zero is not always a valid value** — geographic coordinates stored as 0 are a placeholder just like an empty string.
3. **Missing data can be legitimate** — the missing BBL values for airport and boardwalk restaurants were completely correct.
4. **Drop columns with no data** — a column that is entirely blank adds no value and creates unnecessary clutter.
5. **Investigate in subsets** — filtering down to the affected rows and checking column by column within that subset revealed important differences that a top level audit would have missed.

---

## Step 2e: Standardisation (`Phone number`)

#### Background

Following the geographic column audit, the PHONE column was identified as having 6 blank values. A targeted investigation was conducted before any action was taken.

#### Investigation findings

A GROUP BY query identified the unique restaurants behind the 6 blank rows. It returned only **one unique restaurant** — VAN LEEUWEN ICE CREAM at 224 Front Street, Manhattan (CAMIS `50088489`). The 6 blank rows all belonged to the same restaurant appearing across multiple inspection records.

#### Decision — convert to NULL rather than populate

A current phone number for this restaurant was found via a Google search. However the decision was made to convert to NULL rather than populate the field because:

- The inspections span multiple years and the current phone number found online cannot be verified as accurate for the period covered by the inspections
- The PHONE column has no analytical value for any of the four analysis questions
- Populating a value that cannot be verified from the original data source introduces uncertainty — NULL is always more honest than an unverifiable value
- Consistency — every other missing value throughout the cleaning process was handled by converting to NULL

#### Standardisation — formatting phone numbers with dashes

After handling the blank values a standardisation step was applied. The raw phone numbers were stored as unformatted 10 digit strings such as `2125290539`. These were reformatted to the standard US format with dashes such as `212-529-0539`, using SUBSTRING to extract each segment and CONCAT to join them:

- Characters 1 to 3 — area code
- Dash
- Characters 4 to 6 — exchange code
- Dash
- Characters 7 to 10 — subscriber number

A preview query was run first, then the UPDATE applied with a `WHERE PHONE IS NOT NULL` clause to protect the NULL value set for Van Leeuwen Ice Cream from being processed by the formatting update.

#### Key lessons for future projects


---

## Street name standardisation

#### Issue 3 — Typos and misspellings

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

EXT was flagged as a potential risk before inclusion in the bulk update. Investigation revealed that EXT appeared inside legitimate words such as EXTERIOR STREET and EXTRA PLACE — a bulk replacement would have corrupted these to EXTENSIONRIOR STREET and EXTENSIONRA PLACE. Only 2 rows genuinely needed fixing and these were handled with a targeted manual update:

```sql
UPDATE nyc_restaraunt_inspections.nyc_inspections
SET STREET = 'FLATBUSH AVENUE EXTENSION'
WHERE STREET = 'FLATBUSH AVENUE EXT';
```

PK similarly appeared in only 12 rows across two street names — MORRIS PK AVENUE and EDERLE TERRACE FLUSHING MEADOW CORONA PK. Both were confirmed as PARK abbreviations and fixed with targeted manual updates.

**AVENUE OF TH AMER:**

During the typo fix the value `AVENUE OF TH AMER` was updated to `AVENUE OF THE AMERICAS`. This was based on geographical knowledge of New York City where Avenue of the Americas is a well known Manhattan avenue also known as 6th Avenue. This change highlighted an important data cleaning principle — geographical assumptions should always be verified against other columns in the dataset (such as BORO and ZIPCODE) rather than applied on the basis of assumed knowledge alone. Avenue of the Americas runs through Manhattan with ZIP codes in the 10001 to 10036 range, so cross referencing those columns confirms the change.

**How many rows were affected:** 120 across all typo fixes. Verification: count of rows containing original typo values returned 0.

#### Issue 4 — Compass direction abbreviations

Streets beginning with a single compass letter such as `S CONDUIT AVENUE`, `N CONDUIT AVENUE`, `E FORDHAM ROAD` and `W 42ND STREET` were investigated.

Before making any changes a full investigation was conducted. A query returned all streets starting with N, S, E or W followed by a space, and the results were reviewed carefully:

- All W entries were confirmed as West — Manhattan's grid system divides streets into East and West from 5th Avenue
- All E entries were confirmed as East for the same reason
- N CONDUIT AVENUE was confirmed as North Conduit Avenue in Queens
- S CONDUIT AVENUE, S 8TH AVENUE, S 5TH STREET and others were confirmed as South — Brooklyn's Williamsburg neighbourhood uses North and South designations for some streets

**Key distinction established:** Single compass letters at the START of a street name are compass direction abbreviations. Single letters at the END of a street name such as AVENUE S and AVENUE N are genuine street names from Brooklyn's lettered avenue grid and must not be changed.

**Action taken:** The `^` anchor was used in REGEXP_REPLACE to ensure only letters at the very start of the street name were replaced:

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

#### Issue 5 — Ordinal suffixes on numbered streets

Numbered streets were found to appear without ordinal suffixes throughout the dataset. For example `3 AVENUE` instead of `3RD AVENUE` and `86 STREET` instead of `86TH STREET`.

**Decision made:** After reviewing the four analysis questions it was determined that ordinal suffix standardisation was not necessary. The analysis questions operate at borough, neighbourhood, cuisine and violation level. The exact format of a street number has no impact on any analytical outcome. The transformation was also identified as the most technically complex change attempted during cleaning, carrying meaningful risk of corrupting street names if the ordinal rules were not implemented perfectly.

**Action taken:** None — consciously deferred as not required for analysis.

**Key lesson:** Knowing when not to clean something is as important as knowing when to clean it. Every data cleaning decision should be driven by whether it improves the quality of the analysis. Changes that introduce risk without delivering analytical benefit should be avoided.

#### Key lessons for future projects

1. **Always preview before updating** — every single change in this section was previewed on a sample of rows before being applied to the full dataset. This caught potential issues such as the EXT risk before any damage could be done.
2. **Count affected rows before updating** — knowing exactly how many rows will change before running an update is essential for verifying the result afterwards.
3. **Word boundaries matter** — using `\b` in regex patterns prevented abbreviations from being incorrectly matched inside longer words. Without this ST would have matched inside STREET and AVE inside AVENUE.
4. **Understand the geography before standardising addresses** — New York City has unusual street naming conventions including lettered avenues and directional designations that differ from standard expectations.
5. **Verify assumptions against other columns** — the AVENUE OF TH AMER situation demonstrated that geographical assumptions should always be cross referenced against other available data such as borough and ZIP code before being applied.
6. **Know when to stop** — the ordinal suffix decision demonstrated that analytical relevance should drive every cleaning decision.

---

## Step 2g: Standardising (`Dates: Column and Value`)

#### Background

Three columns in the dataset — INSPECTION DATE, GRADE DATE and RECORD DATE — were identified as being stored as text strings rather than proper date values. While the dates looked correct visually they were technically just text in the format `MM/DD/YYYY`. This meant MySQL could not perform any date based calculations or comparisons on them, which would have been a significant limitation for the third analysis question about how violations vary over time.

#### Verification before converting

Before making any changes the columns were checked to confirm all dates consistently followed the same `MM/DD/YYYY` format, no unexpected values or placeholder dates remained, NULL values in GRADE DATE were displaying correctly, and RECORD DATE was consistent across all rows showing `09/18/2025` as the dataset extract date.

#### The conversion process

**Step 1 — Preview the conversion**

`STR_TO_DATE` was used to translate the text dates into proper MySQL date format. A preview was run first on 10 rows.

**Step 2 — Update all three columns**

Once the preview was confirmed the UPDATE was applied to all rows using `STR_TO_DATE(column, '%m/%d/%Y')`.

**Step 3 — Alter the column data types**

Converting the values alone was not sufficient — the columns were still defined as text in the table structure. The data types were altered to DATE to make the change permanent and recognised by MySQL:

```sql
ALTER TABLE nyc_restaraunt_inspections.nyc_inspections
MODIFY COLUMN `INSPECTION DATE` DATE,
MODIFY COLUMN `GRADE DATE` DATE,
MODIFY COLUMN `RECORD DATE` DATE;
```

All three columns now display in MySQL standard DATE format `YYYY-MM-DD`. NULL values in GRADE DATE are preserved correctly.

#### What STR_TO_DATE does

STR_TO_DATE acts as a translator. The dates were stored as text strings that MySQL could not interpret as dates. It reads the text and converts it into a proper date using a format string to understand the structure: `%m` two digit month, `%d` two digit day, `%Y` four digit year, `/` the separator. Without this conversion MySQL would treat `08/24/2022` as plain text, meaning date arithmetic, date filtering and time series analysis would all either fail or produce incorrect results.

#### Why this matters for analysis

Converting date columns to proper DATE format unlocks filtering inspections by year, month or date range, calculating time between inspection and grading, identifying trends in violations over time, and grouping inspections for time series analysis — all of which are required for Question 3.

#### Key lessons for future projects

1. **Always check the format before converting** — confirming all dates follow the same format before running STR_TO_DATE prevents errors from inconsistent date strings causing NULL values.
2. **Converting values is not enough** — changing the stored values without also altering the column data type means MySQL still treats the column as text. Always run the ALTER TABLE step after the UPDATE.
3. **Preview before updating** — running STR_TO_DATE on a LIMIT 10 sample first confirms the conversion logic is correct before applying it to 285,177 rows.
4. **NULL values are preserved correctly** — STR_TO_DATE on a NULL value returns NULL rather than an error.
