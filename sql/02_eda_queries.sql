-- =====================================
-- VALIDATION
-- =====================================

-- name: raw_count
SELECT COUNT(*) FROM website_traffic;

-- name: clean_count
SELECT COUNT(*) FROM clean;

-- name: clean_behavior_count
SELECT COUNT(*) FROM clean_behavior;

-- name: duplicate_count
SELECT SUM(is_duplicate) FROM enriched_events;

-- name: noise_event_count
SELECT SUM(is_noise_event) FROM enriched_events;

-- name: sessions_after_clean
SELECT COUNT(DISTINCT session_id) FROM clean;

-- =====================================
-- QUALITY DISTRIBUTION
-- =====================================
-- name: quality_distribution
SELECT
    is_quality,
    COUNT(DISTINCT session_id) AS sessions
FROM final_table
GROUP BY is_quality;


-- =====================================
-- FUNNEL
-- =====================================

-- name: funnel_chart
WITH raw AS (
    SELECT COUNT(*) AS cnt FROM website_traffic
),
clean AS (
    SELECT COUNT(*) AS cnt FROM clean
),
dedup AS (
    SELECT COUNT(*) AS cnt
    FROM enriched_events
    WHERE is_duplicate = 0
),
filtered AS (
    SELECT COUNT(*) AS cnt FROM clean_behavior
),
quality AS (
    SELECT
        is_quality,
        COUNT(DISTINCT session_id) AS cnt
    FROM final_table
    GROUP BY is_quality
)
SELECT
    'raw' AS source,
    'clean' AS target,
    (SELECT cnt FROM clean) AS value
UNION ALL
SELECT
    'clean' AS source,
    'dedup' AS target,
    (SELECT cnt FROM dedup) AS value
UNION ALL
SELECT
    'dedup' AS source,
    'filtered' AS target,
    (SELECT cnt FROM filtered) AS value
UNION ALL
SELECT
    'filtered' AS source,
    'quality_1' AS target,
    COALESCE((SELECT cnt FROM quality WHERE is_quality = 1), 0) AS value
UNION ALL
SELECT
    'filtered' AS source,
    'quality_2' AS target,
    COALESCE((SELECT cnt FROM quality WHERE is_quality = 2), 0) AS value
UNION ALL
SELECT
    'filtered' AS source,
    'quality_3' AS target,
    COALESCE((SELECT cnt FROM quality WHERE is_quality = 3), 0) AS value;


-- =====================================
-- 1. DATA OVERVIEW
-- =====================================

-- name: table_info
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT client_id) AS client_id_unique,
    COUNT(DISTINCT session_id) AS session_id_unique,
    COUNT(DISTINCT utm_content) AS utm_content_unique,
    AVG(time_on_site) AS avg_time_on_site,
    AVG(scroll_depth) AS avg_scroll_depth
FROM final_table;


-- =====================================
-- 2. QUALITY DISTRIBUTION
-- =====================================

-- name: quality_distribution
WITH base AS (
    SELECT
        session_id,
        client_id,
        is_quality,
        time_on_site,
        pages_viewed,
        scroll_depth
    FROM final_table
),
agg AS (
    SELECT
        is_quality,
        COUNT(DISTINCT session_id) AS sessions,
        COUNT(DISTINCT client_id) AS users,
        AVG(time_on_site) AS avg_time,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY time_on_site) AS median_time,
        AVG(pages_viewed) AS pages_per_session,
        AVG(scroll_depth) AS avg_scroll_depth,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY scroll_depth) AS median_scroll_depth,
        SUM(time_on_site) AS total_time
    FROM base
    GROUP BY is_quality
),
total AS (
    SELECT
        SUM(sessions) AS total_sessions,
        SUM(users) AS total_users
    FROM agg
)
SELECT
    a.is_quality,
    a.sessions,
    a.sessions * 100.0 / t.total_sessions AS traffic_share,
    a.users,
    a.users * 100.0 / t.total_users AS user_share,
    a.avg_time,
    a.median_time,
    a.pages_per_session,
    a.avg_scroll_depth,
    a.median_scroll_depth,
    a.total_time
FROM agg a
CROSS JOIN total t
ORDER BY a.is_quality;


-- =====================================
-- 3. TRAFFIC SOURCES
-- =====================================

-- name: sources_traffic
SELECT
    utm_content AS ad_placement,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT client_id) AS users,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 1) * 100.0
        / COUNT(DISTINCT session_id) AS weak_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 2) * 100.0
        / COUNT(DISTINCT session_id) AS medium_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 3) * 100.0
        / COUNT(DISTINCT session_id) AS strong_share,
    COUNT(DISTINCT session_id) * 100.0
        / SUM(COUNT(DISTINCT session_id)) OVER () AS traffic_share
FROM final_table
GROUP BY utm_content
ORDER BY sessions DESC;


-- =====================================
-- 4. TEMPORAL ANALYSIS
-- =====================================

-- name: traffic_by_hour
SELECT
    EXTRACT(HOUR FROM client_timestamp) AS hour,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 1) * 100.0
        / COUNT(DISTINCT session_id) AS weak_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 2) * 100.0
        / COUNT(DISTINCT session_id) AS medium_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 3) * 100.0
        / COUNT(DISTINCT session_id) AS strong_share,
    COUNT(DISTINCT session_id) * 100.0
        / SUM(COUNT(DISTINCT session_id)) OVER () AS traffic_share
FROM final_table
GROUP BY hour
ORDER BY hour;


-- name: traffic_by_day
SELECT
    EXTRACT(DOW FROM client_timestamp) AS day_of_week,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 1) * 100.0
        / COUNT(DISTINCT session_id) AS weak_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 2) * 100.0
        / COUNT(DISTINCT session_id) AS medium_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 3) * 100.0
        / COUNT(DISTINCT session_id) AS strong_share,
    COUNT(DISTINCT session_id) * 100.0
        / SUM(COUNT(DISTINCT session_id)) OVER () AS traffic_share
FROM final_table
GROUP BY day_of_week
ORDER BY day_of_week;


-- =====================================
-- 5. PAGE ANALYSIS
-- =====================================

-- name: pages_distribution
SELECT
    page_path,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT client_id) AS users,
    AVG(time_on_site) AS avg_time,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY time_on_site) AS median_time,
    AVG(scroll_depth) AS avg_scroll_depth,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY scroll_depth) AS median_scroll_depth,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 1) * 100.0
        / COUNT(DISTINCT session_id) AS weak_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 2) * 100.0
        / COUNT(DISTINCT session_id) AS medium_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 3) * 100.0
        / COUNT(DISTINCT session_id) AS strong_share,
    COUNT(DISTINCT session_id) * 100.0
        / SUM(COUNT(DISTINCT session_id)) OVER () AS traffic_share
FROM final_table
GROUP BY page_path
ORDER BY sessions DESC;


-- =====================================
-- 6. DEVICE ANALYSIS
-- =====================================

-- name: device_distribution
WITH parsed AS (
    SELECT
        *,
        SPLIT_PART(screen_resolution, 'x', 1)::int AS width
    FROM final_table
),
segmented AS (
    SELECT
        *,
        CASE
            WHEN width <= 360 THEN 'small_mobile'
            WHEN width <= 480 THEN 'large_mobile'
            WHEN width <= 768 THEN 'tablet'
            WHEN width <= 1280 THEN 'small_desktop'
            WHEN width <= 1920 THEN 'desktop'
            ELSE 'large_desktop'
        END AS screen_group
    FROM parsed
)
SELECT
    screen_group,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 1) * 100.0
        / COUNT(DISTINCT session_id) AS low_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 2) * 100.0
        / COUNT(DISTINCT session_id) AS medium_share,
    COUNT(DISTINCT session_id) FILTER (WHERE is_quality = 3) * 100.0
        / COUNT(DISTINCT session_id) AS high_share,
    COUNT(DISTINCT session_id) * 100.0
        / SUM(COUNT(DISTINCT session_id)) OVER () AS traffic_share
FROM segmented
GROUP BY screen_group
ORDER BY sessions DESC;
