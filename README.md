# Operational Incident KPI Analysis

**Tools:** PostgreSQL · Power BI · SQL  
**Context:** Financial & Regulated Operations  
**Dataset:** [Chicago 311 Service Requests](https://www.kaggle.com/datasets/chicago/chicago-311-service-requests) (public)

---

## Overview

This project analyzes operational incident data to surface the KPIs a **GRC or Operations Analyst** would monitor in a regulated financial environment — including SLA compliance rates, recurrence patterns, escalation trends, and resolution benchmarks.

All queries are written in **PostgreSQL** and structured to support executive reporting and Power BI dashboard integration. The analytical framing mirrors how an operations analyst would approach incident governance in a financial institution: data quality first, KPI computation second, executive-ready output third.

---

## Business Questions Answered

| # | Question | SQL Query |
|---|----------|-----------|
| 1 | Which incident categories are trending up month-over-month? | `incident_kpi_analysis.sql` Q1 |
| 2 | What is our SLA compliance rate by severity level? | Q2 |
| 3 | Which incident types take longest to resolve, and why? | Q3 |
| 4 | What are our top 10 highest-volume recurring incident types? | Q4 |
| 5 | How has incident volume changed month-over-month? | Q5 |
| 6 | Which departments have the largest open backlog? | Q6 |
| 7 | Which specific incidents breached SLA and require escalation? | Q7 |
| 8 | What does the rolling 7-day trend look like? | Q8 |
| 9 | What is our first contact resolution rate by category? | Q9 |
| 10 | Which incidents recurred within 30 days — indicating systemic issues? | Q10 |
| 11 | On which days of the week does incident volume peak? | Q11 |
| 12 | Which departments have the highest escalation rates? | Q12 |
| 13 | What is the one-row executive KPI summary? | Q13 |
| 14 | Are there data quality issues that would affect reporting accuracy? | Q14 |
| 15 | What does the Power BI source view expose? | Q15 (view) |

---

## Key Findings

- **1,052,679 graffiti incidents** analyzed across Chicago (2001–2019)
- **Average resolution time: 7.4 days** citywide against a 168-hour (7-day) SLA target
- **SLA breach rate: 11%** — 115,443 incidents exceeded the resolution target
- **Near-zero open backlog:** Only 146 incidents remain open — a 99.99% closure rate
- **Geographic disparity identified:** ZIP code 60643 averages 53.4 days to resolve — 7× slower than the city average despite lower volume, suggesting a resource allocation gap
- **Peak demand:** March 2011 recorded the highest single-month volume at 16,281 incidents
- **High-volume ZIP 60629** handled 57,180 incidents at 19.7 days average — demonstrating that high volume does not correlate with slower resolution

---

## SQL Concepts Demonstrated

| Concept | Used In |
|---------|---------|
| `DATE_TRUNC`, `EXTRACT` | Q1, Q5, Q8, Q11 |
| `CASE WHEN` logic | Q2, Q7, Q9, Q12 |
| Window functions — `RANK()`, `LAG()`, `SUM OVER`, `PERCENTILE_CONT` | Q4, Q5, Q8, Q10 |
| CTEs (`WITH` clauses) | Q5, Q13 |
| Self-JOIN for recurrence detection | Q10 |
| `FILTER` clause | Q2, Q6, Q9, Q12 |
| `UNION ALL` for audit reporting | Q14 |
| `CREATE OR REPLACE VIEW` | Q15 |
| Aggregation with `NULLIF` for safe division | Q2, Q6, Q12 |

---

## Project Structure

```
ops-incident-analysis/
├── incident_kpi_analysis.sql    # All 15 queries + setup + kpi_summary view
├── README.md                    # This file
└── screenshots/
    ├── q2_sla_compliance.png    # Sample output — SLA compliance by severity
    ├── q13_exec_summary.png     # Sample output — executive KPI row
    └── powerbi_dashboard.png    # Dashboard screenshot (see live link below)
```

---

## Power BI Dashboard

**Live dashboard:** [Insert Power BI Service URL here after publishing in Week 4]

The dashboard connects directly to the `kpi_summary` view (Query 15) and includes:
- KPI card row: total incidents, SLA compliance %, avg resolution time, open backlog
- Incident volume trend line with MoM change
- Top categories bar chart with SLA breach rate overlay
- Day-of-week incident heatmap
- SLA compliance gauge vs. 95% target
- Interactive slicers: date range, severity, category

---

## How to Run This Project

### 1. Prerequisites
- [PostgreSQL](https://www.postgresql.org/download/) installed locally
- Dataset downloaded from [Kaggle](https://www.kaggle.com/datasets/chicago/chicago-311-service-requests)

### 2. Load the dataset

```sql
-- Create the raw import table (adjust column names to match your CSV)
CREATE TABLE chicago_311_raw (
    service_request_id   TEXT,
    sr_type              TEXT,
    sr_short_code        TEXT,
    owner_department     TEXT,
    status               TEXT,
    created_date         TEXT,
    closed_date          TEXT,
    latitude             TEXT,
    longitude            TEXT
);

-- Import via psql
\COPY chicago_311_raw FROM 'path/to/311_service_requests.csv'
    WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '\');
```

### 3. Run the analysis

```bash
psql -U your_username -d your_database -f incident_kpi_analysis.sql
```

### 4. Connect Power BI
- Open Power BI Desktop → Get Data → PostgreSQL
- Host: `localhost` | Database: `your_database`
- Table/View: `kpi_summary`

---

## About This Project

This analysis was built as part of a portfolio project to demonstrate SQL and BI skills in an operational/GRC context. The dataset is public and fully anonymized. The analytical framing — SLA governance, escalation tracking, recurrence detection, audit-ready data quality checks — reflects real responsibilities in financial operations and risk management roles.

**Author:** Yusuf Masood  
**LinkedIn:** [linkedin.com/in/yusufmasood](https://linkedin.com/in/yusufmasood)  
**Portfolio:** [github.com/yusufmasood](https://github.com/yusufmasood)
