-- =====================================================================
-- NYC Restaurant Inspection Analysis - EXPLORATORY ANALYSIS
-- Four analysis questions. Engine: MySQL
-- =====================================================================


-- ---------------------------------------------------------------------
-- QUESTION 1: Which violations are most common, and where?
-- ---------------------------------------------------------------------

-- Step 1: most common violations citywide
SELECT
    `VIOLATION CODE`,
    `VIOLATION DESCRIPTION`,
    COUNT(*) AS violation_count
FROM nyc_restaraunt_inspections.nyc_inspections
WHERE `VIOLATION DESCRIPTION` IS NOT NULL AND `VIOLATION DESCRIPTION` != ''
AND `VIOLATION CODE` IS NOT NULL AND `VIOLATION CODE` != ''
GROUP BY `VIOLATION CODE`, `VIOLATION DESCRIPTION`
ORDER BY violation_count DESC;

-- Step 2: by borough
SELECT
    BORO,
    `VIOLATION DESCRIPTION`,
    `VIOLATION CODE`,
    COUNT(*) AS violation_count
FROM nyc_restaraunt_inspections.nyc_inspections
WHERE `VIOLATION DESCRIPTION` IS NOT NULL AND BORO IS NOT NULL
GROUP BY BORO, `VIOLATION DESCRIPTION`, `VIOLATION CODE`
ORDER BY BORO, violation_count DESC;

-- Step 3: top 5 per borough (CTE + ROW_NUMBER partitioned by borough)
WITH violation_rankings AS (
    SELECT
        BORO,
        `VIOLATION DESCRIPTION`,
        `VIOLATION CODE`,
        COUNT(*) AS violation_count,
        ROW_NUMBER() OVER (
            PARTITION BY BORO
            ORDER BY COUNT(*) DESC
        ) AS rank_num
    FROM nyc_restaraunt_inspections.nyc_inspections
    WHERE `VIOLATION DESCRIPTION` IS NOT NULL
    AND BORO IS NOT NULL
    GROUP BY BORO, `VIOLATION DESCRIPTION`, `VIOLATION CODE`
)
SELECT BORO, `VIOLATION DESCRIPTION`, `VIOLATION CODE`, violation_count, rank_num
FROM violation_rankings
WHERE rank_num <= 5
ORDER BY BORO, rank_num;

-- Step 4: add CRITICAL FLAG for severity context
WITH violation_rankings AS (
    SELECT
        BORO,
        `VIOLATION DESCRIPTION`,
        `VIOLATION CODE`,
        `CRITICAL FLAG`,
        COUNT(*) AS violation_count,
        ROW_NUMBER() OVER (
            PARTITION BY BORO
            ORDER BY COUNT(*) DESC
        ) AS rank_num
    FROM nyc_restaraunt_inspections.nyc_inspections
    WHERE `VIOLATION DESCRIPTION` IS NOT NULL
    AND BORO IS NOT NULL
    GROUP BY BORO, `VIOLATION DESCRIPTION`, `VIOLATION CODE`, `CRITICAL FLAG`
)
SELECT BORO, `VIOLATION DESCRIPTION`, `VIOLATION CODE`, `CRITICAL FLAG`, violation_count, rank_num
FROM violation_rankings
WHERE rank_num <= 5
ORDER BY BORO, rank_num;


-- ---------------------------------------------------------------------
-- QUESTION 2: Which cuisines and neighbourhoods perform worst?
-- Three metrics: avg score, critical %, grade distribution
-- ---------------------------------------------------------------------
SELECT
    `CUISINE DESCRIPTION`,
    BORO,
    COUNT(SCORE) AS score_count,
    AVG(SCORE) AS avg_score,
    ROUND(
        SUM(CASE WHEN `CRITICAL FLAG` = 'Critical' THEN 1 ELSE 0 END) / COUNT(`CRITICAL FLAG`) * 100
    , 2) AS critical_percentage,
    ROUND(SUM(CASE WHEN GRADE = 'A' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeA,
    ROUND(SUM(CASE WHEN GRADE = 'B' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeB,
    ROUND(SUM(CASE WHEN GRADE = 'C' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeC,
    ROUND(SUM(CASE WHEN GRADE = 'N' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeN,
    ROUND(SUM(CASE WHEN GRADE = 'Z' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeZ,
    ROUND(SUM(CASE WHEN GRADE = 'P' THEN 1 ELSE 0 END) / COUNT(GRADE) * 100, 2) AS gradeP
FROM nyc_inspections
GROUP BY `CUISINE DESCRIPTION`, BORO
ORDER BY avg_score DESC;


-- ---------------------------------------------------------------------
-- QUESTION 3: How do grades and violations vary by borough and time?
-- Time dimension = INSPECTION DATE, year-level granularity
-- ---------------------------------------------------------------------

-- Part A: grades by borough and year
SELECT
    YEAR(`INSPECTION DATE`) AS `inspection year`,
    BORO,
    GRADE,
    COUNT(GRADE) AS grade_count
FROM nyc_inspections
WHERE GRADE IS NOT NULL AND GRADE != '' AND YEAR(`INSPECTION DATE`) >= 2022
GROUP BY YEAR(`INSPECTION DATE`), BORO, GRADE
ORDER BY BORO, YEAR(`INSPECTION DATE`), GRADE;

-- Part B: violation frequency by borough and year
-- NOTE: the GRADE IS NOT NULL filter from Part A was deliberately removed here.
-- Leaving it in undercounts violations on ungraded inspections.
SELECT
    YEAR(`INSPECTION DATE`) AS `inspection year`,
    BORO,
    `VIOLATION CODE`,
    COUNT(`VIOLATION CODE`) AS violation_code_count
FROM nyc_inspections
WHERE YEAR(`INSPECTION DATE`) >= 2022
AND `VIOLATION CODE` IS NOT NULL AND `VIOLATION CODE` != ''
GROUP BY YEAR(`INSPECTION DATE`), BORO, `VIOLATION CODE`
ORDER BY BORO, YEAR(`INSPECTION DATE`), violation_code_count DESC;


-- ---------------------------------------------------------------------
-- QUESTION 4: Where should the city focus?
-- Synthesis question. New SQL = NTA-level neighbourhood targeting.
-- ---------------------------------------------------------------------
SELECT
    NTA,
    BORO,
    COUNT(SCORE) AS score_count,
    AVG(SCORE) AS avg_score,
    ROUND(
        SUM(CASE WHEN `CRITICAL FLAG` = 'Critical' THEN 1 ELSE 0 END) / COUNT(*) * 100
    , 2) AS critical_percentage
FROM nyc_inspections
WHERE NTA IS NOT NULL AND NTA != ''
GROUP BY NTA, BORO
ORDER BY BORO, avg_score DESC;
