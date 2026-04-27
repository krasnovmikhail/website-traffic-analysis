-- =====================================
-- 1. DATA CLEANING
-- =====================================

-- Remove test traffic
CREATE TEMP TABLE clean AS
SELECT *
FROM website_traffic
WHERE timezone <> 'Asia/Bangkok';


-- =====================================
-- 2. EVENT ENRICHMENT
-- =====================================

-- Add flags: duplicates, noise, behavior
CREATE TEMP TABLE enriched_events AS
SELECT
    *,
    CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY session_id, client_timestamp, page_path
            ORDER BY event_type
        ) > 1 THEN 1 ELSE 0
    END AS is_duplicate,

    CASE
        WHEN event_type != 'behavior' THEN 1 ELSE 0
    END AS is_noise_event,

    CASE
        WHEN event_type = 'behavior' THEN 1 ELSE 0
    END AS is_behavior
FROM clean;


-- =====================================
-- 3. FILTER VALID EVENTS
-- =====================================

CREATE TEMP TABLE clean_behavior AS
SELECT *
FROM enriched_events
WHERE is_duplicate = 0
  AND is_behavior = 1;


-- =====================================
-- 4. SESSION AGGREGATION
-- =====================================

CREATE TEMP TABLE session_quality AS
SELECT
    session_id,
    SUM(time_on_site) AS total_time,
    SUM(pages_viewed) AS total_pages
FROM clean_behavior
GROUP BY session_id;


-- =====================================
-- 5. FINAL DATASET
-- =====================================

CREATE TEMP TABLE final_table AS
SELECT
    cb.*,
    CASE
        WHEN sq.total_time <= 5 THEN 1
        WHEN sq.total_time > 15 AND sq.total_pages >= 2 THEN 3
        ELSE 2
    END AS is_quality
FROM clean_behavior cb
LEFT JOIN session_quality sq
    ON cb.session_id = sq.session_id;
