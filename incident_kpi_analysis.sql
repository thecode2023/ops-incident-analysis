-- ============================================================
-- OPERATIONAL INCIDENT KPI ANALYSIS
-- Author: Yusuf Masood | github.com/yusufmasood
-- Dataset: Chicago 311 Service Requests (public)
-- Tool: PostgreSQL
-- Context: Simulates the KPI reporting a GRC or Operations
--          Analyst would produce in a regulated financial
--          environment (incident tracking, SLA governance,
--          escalation analysis, executive reporting).
-- ============================================================


-- ============================================================
-- SETUP: Create normalized incident table from raw 311 data
-- Run this first to create a clean working table.
-- ============================================================

DROP TABLE IF EXISTS incidents;

CREATE TABLE incidents AS
SELECT
    service_request_id::TEXT                        AS incident_id,
    sr_type::TEXT                                   AS category,
    sr_short_code::TEXT                             AS category_code,
    owner_department::TEXT                          AS department,
    status::TEXT                                    AS status,
    -- Severity derived from request type (adapt to your dataset)
    CASE
        WHEN LOWER(sr_type) LIKE '%emergency%'      THEN 'Critical'
        WHEN LOWER(sr_type) LIKE '%urgent%'         THEN 'High'
        WHEN LOWER(sr_type) LIKE '%water%'          THEN 'Medium'
        ELSE 'Low'
    END                                             AS severity,
    created_date::TIMESTAMP                         AS created_at,
    closed_date::TIMESTAMP                          AS closed_at,
    -- SLA target: 72 hrs for High/Critical, 168 hrs (7 days) for Low/Medium
    CASE
        WHEN LOWER(sr_type) LIKE '%emergency%'
          OR LOWER(sr_type) LIKE '%urgent%'         THEN 72
        ELSE 168
    END                                             AS sla_target_hours,
    latitude::NUMERIC                               AS lat,
    longitude::NUMERIC                              AS lon
FROM chicago_311_raw   -- rename to match your imported table name
WHERE created_date IS NOT NULL;

-- Add a computed column: resolution hours
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS resolution_hours NUMERIC;
UPDATE incidents
SET resolution_hours = EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600.0
WHERE closed_at IS NOT NULL;

-- Add SLA breach flag
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS sla_breached BOOLEAN;
UPDATE incidents
SET sla_breached = CASE
    WHEN closed_at IS NOT NULL
     AND resolution_hours > sla_target_hours THEN TRUE
    ELSE FALSE
END;


-- ============================================================
-- QUERY 1: Incident volume by category and month
-- Business purpose: Identify trending incident types over time.
--   A GRC analyst uses this to spot emerging risk patterns and
--   allocate operational resources proactively.
-- ============================================================

SELECT
    DATE_TRUNC('month', created_at)         AS month,
    category,
    COUNT(*)                                AS incident_count
FROM incidents
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;


-- ============================================================
-- QUERY 2: SLA compliance rate overall and by severity
-- Business purpose: Core governance KPI. In a regulated
--   environment, SLA compliance is reported to senior leadership
--   and auditors. Falling below threshold triggers escalation.
-- ============================================================

SELECT
    severity,
    COUNT(*)                                                    AS total_incidents,
    SUM(CASE WHEN NOT sla_breached AND closed_at IS NOT NULL
             THEN 1 ELSE 0 END)                                 AS closed_within_sla,
    COUNT(*) FILTER (WHERE closed_at IS NOT NULL)               AS total_closed,
    ROUND(
        100.0 * SUM(CASE WHEN NOT sla_breached
                          AND closed_at IS NOT NULL THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*) FILTER (WHERE closed_at IS NOT NULL), 0),
    2)                                                          AS sla_compliance_pct
FROM incidents
GROUP BY severity
ORDER BY
    CASE severity
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        WHEN 'Medium'   THEN 3
        WHEN 'Low'      THEN 4
    END;


-- ============================================================
-- QUERY 3: Average resolution time by category and severity
-- Business purpose: Identifies which incident types take longest
--   to resolve. Feeds into resource planning and process
--   improvement initiatives.
-- ============================================================

SELECT
    category,
    severity,
    COUNT(*) FILTER (WHERE closed_at IS NOT NULL)   AS resolved_count,
    ROUND(AVG(resolution_hours), 1)                 AS avg_resolution_hrs,
    ROUND(PERCENTILE_CONT(0.5)
          WITHIN GROUP (ORDER BY resolution_hours)
          ::NUMERIC, 1)                             AS median_resolution_hrs,
    ROUND(MAX(resolution_hours), 1)                 AS max_resolution_hrs
FROM incidents
WHERE closed_at IS NOT NULL
GROUP BY category, severity
ORDER BY avg_resolution_hrs DESC
LIMIT 20;


-- ============================================================
-- QUERY 4: Top 10 recurring incident types by volume
-- Business purpose: Frequency ranking surfaces which categories
--   consume the most operational capacity — essential input for
--   a Business Analyst recommending process automation or
--   resource reallocation.
-- ============================================================

SELECT
    category,
    COUNT(*)                                    AS total_incidents,
    RANK() OVER (ORDER BY COUNT(*) DESC)        AS volume_rank,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*))
          OVER (), 2)                           AS pct_of_total,
    ROUND(AVG(resolution_hours), 1)             AS avg_resolution_hrs,
    ROUND(AVG(CASE WHEN sla_breached THEN 1.0
                   ELSE 0.0 END) * 100, 1)      AS sla_breach_rate_pct
FROM incidents
GROUP BY category
ORDER BY total_incidents DESC
LIMIT 10;


-- ============================================================
-- QUERY 5: Month-over-month incident volume change
-- Business purpose: Trend analysis for executive reporting.
--   A positive MoM spike triggers operational review. LAG()
--   is the standard window function for period comparisons.
-- ============================================================

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', created_at)     AS month,
        COUNT(*)                            AS incident_count
    FROM incidents
    GROUP BY 1
)
SELECT
    month,
    incident_count,
    LAG(incident_count) OVER (ORDER BY month)   AS prior_month_count,
    incident_count
      - LAG(incident_count) OVER (ORDER BY month)  AS mom_change,
    ROUND(
        100.0 * (incident_count
          - LAG(incident_count) OVER (ORDER BY month))
        / NULLIF(LAG(incident_count) OVER (ORDER BY month), 0),
    1)                                           AS mom_change_pct
FROM monthly
ORDER BY month DESC;


-- ============================================================
-- QUERY 6: Open vs. closed backlog by department
-- Business purpose: Backlog tracking is a key operational health
--   metric. High open counts in a specific department signal
--   a capacity or process problem requiring BA intervention.
-- ============================================================

SELECT
    department,
    COUNT(*) FILTER (WHERE status = 'Open')         AS open_count,
    COUNT(*) FILTER (WHERE status = 'Closed')       AS closed_count,
    COUNT(*)                                        AS total,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'Open')
              / NULLIF(COUNT(*), 0),
    1)                                              AS open_rate_pct
FROM incidents
GROUP BY department
ORDER BY open_count DESC;


-- ============================================================
-- QUERY 7: Incidents breaching SLA — escalation candidates
-- Business purpose: This is the operational escalation report.
--   In a financial institution, incidents breaching SLA thresholds
--   are flagged for management review and documented for audit.
-- ============================================================

SELECT
    incident_id,
    category,
    severity,
    department,
    created_at,
    closed_at,
    ROUND(resolution_hours, 1)          AS resolution_hrs,
    sla_target_hours,
    ROUND(resolution_hours
          - sla_target_hours, 1)        AS hrs_over_sla,
    -- Escalation tier based on how far over SLA
    CASE
        WHEN resolution_hours > sla_target_hours * 3 THEN 'Tier 3 – Executive'
        WHEN resolution_hours > sla_target_hours * 2 THEN 'Tier 2 – Manager'
        ELSE                                              'Tier 1 – Supervisor'
    END                                 AS escalation_tier
FROM incidents
WHERE sla_breached = TRUE
  AND closed_at IS NOT NULL
ORDER BY hrs_over_sla DESC
LIMIT 50;


-- ============================================================
-- QUERY 8: Rolling 7-day incident count trend
-- Business purpose: Smooths daily volatility to reveal true
--   operational trends. Used in real-time ops dashboards to
--   detect volume spikes before they become incidents themselves.
-- ============================================================

WITH daily AS (
    SELECT
        created_at::DATE        AS day,
        COUNT(*)                AS daily_count
    FROM incidents
    GROUP BY 1
)
SELECT
    day,
    daily_count,
    SUM(daily_count) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )                           AS rolling_7day_total,
    ROUND(AVG(daily_count) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 1)                       AS rolling_7day_avg
FROM daily
ORDER BY day DESC;


-- ============================================================
-- QUERY 9: First contact resolution (FCR) rate by category
-- Business purpose: FCR is a primary service quality KPI.
--   High FCR = efficient triage. Low FCR = process gap requiring
--   BA investigation (training, tooling, or workflow redesign).
--
-- Note: "First contact resolved" defined here as closed within
-- 4 hours of creation (adapt to your dataset's definitions).
-- ============================================================

SELECT
    category,
    COUNT(*) FILTER (WHERE closed_at IS NOT NULL)       AS total_resolved,
    COUNT(*) FILTER (
        WHERE closed_at IS NOT NULL
          AND resolution_hours <= 4
    )                                                   AS first_contact_resolved,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE closed_at IS NOT NULL
              AND resolution_hours <= 4
        )
        / NULLIF(COUNT(*) FILTER (
            WHERE closed_at IS NOT NULL), 0),
    1)                                                  AS fcr_rate_pct
FROM incidents
GROUP BY category
HAVING COUNT(*) FILTER (WHERE closed_at IS NOT NULL) >= 50
ORDER BY fcr_rate_pct DESC;


-- ============================================================
-- QUERY 10: Repeat incidents within 30-day window (recurrence)
-- Business purpose: Recurrence analysis identifies systemic
--   issues rather than one-off events. A GRC analyst uses this
--   to recommend root cause analysis and permanent remediation.
-- ============================================================

SELECT
    a.incident_id                           AS incident_id,
    a.category,
    a.department,
    a.created_at                            AS first_occurrence,
    b.created_at                            AS recurrence_date,
    ROUND(EXTRACT(EPOCH FROM
        (b.created_at - a.created_at))
        / 86400.0, 1)                       AS days_between,
    COUNT(*) OVER (
        PARTITION BY a.category, a.department
    )                                       AS recurrence_count
FROM incidents a
JOIN incidents b
    ON  a.category   = b.category
    AND a.department = b.department
    AND b.created_at > a.created_at
    AND b.created_at <= a.created_at + INTERVAL '30 days'
    AND a.incident_id <> b.incident_id
ORDER BY recurrence_count DESC, a.created_at
LIMIT 100;


-- ============================================================
-- QUERY 11: Incident volume by day-of-week (heatmap source)
-- Business purpose: Operational staffing insight. Knowing which
--   days carry highest volume informs shift scheduling and
--   change window planning — directly relevant to IT change
--   management in a financial institution.
-- ============================================================

SELECT
    TO_CHAR(created_at, 'Day')              AS day_name,
    EXTRACT(DOW FROM created_at)            AS day_number,   -- 0=Sun, 6=Sat
    COUNT(*)                                AS incident_count,
    ROUND(AVG(resolution_hours), 1)         AS avg_resolution_hrs,
    ROUND(AVG(CASE WHEN sla_breached
                   THEN 1.0 ELSE 0.0 END)
          * 100, 1)                         AS sla_breach_rate_pct
FROM incidents
GROUP BY 1, 2
ORDER BY 2;


-- ============================================================
-- QUERY 12: Escalation rate by department
-- Business purpose: Departments with high escalation rates
--   indicate either understaffing, insufficient tooling, or
--   process gaps — all actionable findings for a BA to present
--   to leadership with root cause recommendations.
-- ============================================================

SELECT
    department,
    COUNT(*)                                        AS total_incidents,
    -- Proxy: incidents closed >2x SLA target treated as escalated
    COUNT(*) FILTER (
        WHERE resolution_hours > sla_target_hours * 2
    )                                               AS escalated_count,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE resolution_hours > sla_target_hours * 2
        ) / NULLIF(COUNT(*), 0),
    1)                                              AS escalation_rate_pct,
    ROUND(AVG(resolution_hours), 1)                 AS avg_resolution_hrs
FROM incidents
WHERE closed_at IS NOT NULL
GROUP BY department
ORDER BY escalation_rate_pct DESC;


-- ============================================================
-- QUERY 13: Executive summary — 5 KPIs in a single row
-- Business purpose: This is the "executive dashboard query."
--   Using CTEs to compute each KPI independently then SELECT
--   them side-by-side is the standard pattern for exec reporting
--   tables and BI tool connections.
-- ============================================================

WITH
total_vol AS (
    SELECT COUNT(*) AS total FROM incidents
),
sla_rate AS (
    SELECT
        ROUND(100.0 * SUM(CASE WHEN NOT sla_breached
                               AND closed_at IS NOT NULL THEN 1 ELSE 0 END)
                   / NULLIF(COUNT(*) FILTER (WHERE closed_at IS NOT NULL), 0),
              1) AS sla_compliance_pct
    FROM incidents
),
avg_res AS (
    SELECT ROUND(AVG(resolution_hours), 1) AS avg_resolution_hrs
    FROM incidents WHERE closed_at IS NOT NULL
),
open_backlog AS (
    SELECT COUNT(*) AS open_count FROM incidents WHERE status = 'Open'
),
breach_count AS (
    SELECT COUNT(*) AS sla_breaches FROM incidents WHERE sla_breached = TRUE
)
SELECT
    tv.total                    AS total_incidents,
    sr.sla_compliance_pct       AS sla_compliance_pct,
    ar.avg_resolution_hrs       AS avg_resolution_hrs,
    ob.open_count               AS open_backlog,
    bc.sla_breaches             AS total_sla_breaches
FROM total_vol tv, sla_rate sr, avg_res ar, open_backlog ob, breach_count bc;


-- ============================================================
-- QUERY 14: Data quality audit — missing/null SLA fields
-- Business purpose: Before any report goes to leadership or
--   audit, a BA validates data completeness. This query flags
--   records with missing close dates, null categories, or
--   invalid timestamps — standard audit-readiness check.
-- ============================================================

SELECT
    'Missing closed_at'                 AS issue,
    COUNT(*) FILTER (WHERE closed_at IS NULL
                      AND status = 'Closed')    AS affected_records,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE closed_at IS NULL AND status = 'Closed')
        / NULLIF(COUNT(*), 0), 2)               AS pct_of_total
FROM incidents

UNION ALL

SELECT
    'Missing category',
    COUNT(*) FILTER (WHERE category IS NULL OR category = ''),
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE category IS NULL OR category = '')
        / NULLIF(COUNT(*), 0), 2)
FROM incidents

UNION ALL

SELECT
    'Invalid resolution time (negative)',
    COUNT(*) FILTER (WHERE resolution_hours < 0),
    ROUND(100.0 * COUNT(*) FILTER (WHERE resolution_hours < 0)
        / NULLIF(COUNT(*), 0), 2)
FROM incidents

UNION ALL

SELECT
    'Missing department',
    COUNT(*) FILTER (WHERE department IS NULL OR department = ''),
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE department IS NULL OR department = '')
        / NULLIF(COUNT(*), 0), 2)
FROM incidents;


-- ============================================================
-- QUERY 15: CREATE VIEW — kpi_summary (Power BI source)
-- Business purpose: This view becomes the direct data source
--   for the Power BI dashboard in Week 4. Encapsulating KPI
--   logic in a view means the dashboard always reflects
--   current data without query changes.
-- ============================================================

CREATE OR REPLACE VIEW kpi_summary AS
SELECT
    DATE_TRUNC('month', created_at)                         AS month,
    category,
    severity,
    department,

    -- Volume
    COUNT(*)                                                AS incident_count,

    -- Resolution
    COUNT(*) FILTER (WHERE closed_at IS NOT NULL)           AS resolved_count,
    COUNT(*) FILTER (WHERE status = 'Open')                 AS open_count,
    ROUND(AVG(resolution_hours), 1)                         AS avg_resolution_hrs,
    ROUND(PERCENTILE_CONT(0.5)
          WITHIN GROUP (ORDER BY resolution_hours)
          ::NUMERIC, 1)                                     AS median_resolution_hrs,

    -- SLA
    COUNT(*) FILTER (WHERE sla_breached = TRUE)             AS sla_breaches,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE NOT sla_breached
                                  AND closed_at IS NOT NULL)
             / NULLIF(COUNT(*) FILTER (
                 WHERE closed_at IS NOT NULL), 0),
    1)                                                      AS sla_compliance_pct,

    -- Recurrence proxy
    ROUND(AVG(CASE WHEN sla_breached THEN 1.0
                   ELSE 0.0 END) * 100, 1)                  AS breach_rate_pct

FROM incidents
GROUP BY 1, 2, 3, 4;

-- Verify the view
SELECT * FROM kpi_summary ORDER BY month DESC LIMIT 10;
