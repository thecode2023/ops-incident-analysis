# AI Governance Risk Assessment
## Chicago 311 Operations — Hypothetical AI Triage System

---

## Overview

This section extends the ops-incident-analysis project into AI governance territory.  
It models a realistic scenario: **what if the City of Chicago deployed an AI-powered triage and routing system on top of its 311 service request pipeline?**

Given the volume patterns, seasonal trends, and departmental routing complexity surfaced in this dataset, AI-assisted triage is a credible next step for a city of Chicago's scale. This section documents the governance controls that deployment would require — mapped against the **NIST AI Risk Management Framework (AI RMF)** and **OWASP Top 10 for Large Language Models**.

This is not a hypothetical exercise. Cities including Los Angeles, Boston, and New York have already deployed or piloted AI-assisted 311 routing. The risks modeled here are active governance challenges in municipal AI today.

---

## Hypothetical System: AI-311 Triage Engine

**System description:**  
An LLM-powered intake layer sits between the 311 submission interface and departmental routing. It reads incoming request text, classifies service type, estimates priority based on historical patterns, and routes to the appropriate department — reducing manual triage time and improving response SLA compliance.

**Data inputs:**
- Free-text service request descriptions (citizen-submitted)
- Historical request data (this dataset: ~7M+ records)
- Department capacity and SLA data

**Outputs:**
- Service type classification
- Priority score (1–5)
- Department routing recommendation
- Estimated completion window

**Users:** 311 call center staff, departmental supervisors, city operations analysts

---

## Risk Assessment

### Framework Mapping: NIST AI RMF Core Functions

| NIST Function | Risk Domain | Finding | Severity |
|---|---|---|---|
| **GOVERN** | Ownership & Accountability | No defined owner for AI model behavior or prompt configurations | HIGH |
| **GOVERN** | Change Management | System prompts governing AI routing logic have no version control or change audit trail | HIGH |
| **MAP** | Bias & Equity Risk | Dataset shows uneven request resolution times across ZIP codes — AI trained on this data will inherit and amplify disparities | HIGH |
| **MAP** | Data Quality | ~12% of records contain null or inconsistent department codes — direct risk to routing accuracy | MEDIUM |
| **MEASURE** | Performance Monitoring | No defined KPIs for AI triage accuracy; no feedback loop from departmental outcomes back to model | HIGH |
| **MEASURE** | Explainability | Black-box routing decisions not interpretable by 311 staff — reduces ability to catch errors in real time | MEDIUM |
| **MANAGE** | Incident Response | No defined protocol for AI misrouting events or model drift detection | HIGH |
| **MANAGE** | Human Override | No documented escalation path for staff to override or flag AI recommendations | MEDIUM |

---

### OWASP LLM Top 10 — Applied Risk Mapping

| OWASP Risk | Application to AI-311 | Mitigation |
|---|---|---|
| **LLM01 — Prompt Injection** | Malicious actors submit crafted 311 requests designed to manipulate AI routing (e.g., bypass priority queue) | Input sanitization; output validation layer; anomaly detection on routing patterns |
| **LLM02 — Insecure Output Handling** | AI-generated routing recommendations passed directly to departmental systems without validation | Human-in-the-loop review for edge cases; structured output schema enforcement |
| **LLM06 — Sensitive Information Disclosure** | Free-text requests may contain PII (addresses, names, health conditions); AI processing pipeline must not log or expose this | PII detection and redaction before LLM input; data minimization policy |
| **LLM08 — Excessive Agency** | AI system given direct write access to routing queues without human approval step | Principle of least privilege; AI makes recommendations only, humans approve routing for priority cases |
| **LLM09 — Overreliance** | 311 staff defer entirely to AI classification, missing errors or edge cases | Confidence scoring surfaced to staff; mandatory review thresholds for low-confidence outputs |

---

## Equity Risk: The Dataset Tells a Story

One of the most significant governance findings from this dataset is not a technical vulnerability — it is a **data fairness risk**.

Analysis of historical 311 records reveals measurable disparities in:
- **Resolution time by ZIP code** — requests from lower-income ZIP codes show longer average closure times for equivalent service types
- **Request volume vs. resolution rate** — high-volume areas do not show proportionally faster resolution, suggesting resource allocation gaps
- **Department routing consistency** — identical service descriptions routed inconsistently across time periods, indicating human triage variability

An AI system trained on this historical data without bias mitigation will **replicate and potentially amplify** these patterns at scale. This is an AI governance risk that no amount of cybersecurity controls will fix — it requires intentional data auditing, fairness constraints in model training, and ongoing disparity monitoring in production.

**Recommended control:** Pre-deployment bias audit using disaggregated performance metrics across ZIP code, ward, and service type. Ongoing disparity dashboard in production monitoring.

---

## Governance Control Recommendations

### Immediate (Pre-Deployment)
- [ ] Assign a named AI System Owner with documented accountability for model behavior
- [ ] Implement version control for all system prompts and model configuration (treat as Crown Jewel assets)
- [ ] Conduct pre-deployment bias audit across ZIP code and demographic proxies
- [ ] Define AI-specific incident response playbook (misrouting, model drift, data exposure)
- [ ] Establish human override protocol for all AI routing recommendations

### Ongoing (Post-Deployment)
- [ ] Monthly model performance review against defined KPIs (routing accuracy, SLA improvement, disparity metrics)
- [ ] Quarterly prompt integrity audit — verify system prompts have not been modified without change ticket
- [ ] Anomaly detection on routing pattern deviations (potential prompt injection indicator)
- [ ] Annual third-party AI risk assessment aligned to NIST AI RMF

---

## Key Takeaway

The McKinsey/Lilli breach (March 2026) demonstrated that the most dangerous vulnerability in an enterprise AI system may not be the data layer — it may be the **prompt layer**: the instructions governing how the AI thinks and responds, often stored without access controls, version history, or integrity monitoring.

For a public-facing municipal AI system like AI-311, the stakes extend beyond corporate confidentiality. Compromised routing logic means delayed pothole repairs in some neighborhoods and expedited service in others. Poisoned priority scores mean public health and safety requests get deprioritized silently.

**AI governance is not a compliance checkbox. For public sector AI, it is a question of equitable service delivery.**

---

## References

- [NIST AI Risk Management Framework (AI RMF 1.0)](https://airc.nist.gov/RMF)
- [OWASP Top 10 for Large Language Model Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [CodeWall: How We Hacked McKinsey's AI Platform (2026)](https://codewall.ai/research/how-we-hacked-mckinseys-ai-platform)
- [City of Chicago 311 Service Requests — Open Data Portal](https://data.cityofchicago.org/)

---

*This section was developed as part of an independent portfolio project exploring the intersection of public sector operations analytics and AI governance. It does not represent the views of any employer.*
