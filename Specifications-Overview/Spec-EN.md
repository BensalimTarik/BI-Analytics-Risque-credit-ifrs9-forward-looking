# Functional Specifications – IFRS 9 Forward-Looking Credit Risk Analytics

## 1. Project Overview

This project aims to implement a comprehensive analytical and decision-making solution dedicated to assessing, monitoring, and forecasting (**Forward-Looking**) **credit risk under the IFRS 9 standard**.

It enables the extraction, cleansing, centralization, and modeling of loan portfolio data (Lending Club dataset) enriched with official macroeconomic series (**FRED**). The outputs allow risk teams to compute Expected Credit Losses (**ECL**), monitor capital requirements (**RWA / CET1**), benchmark credit scoring models (**LR Retail vs. LR Retail + Macro**), and perform macro stress testing to support strategic risk management decisions.

## 2. Business Objectives

The overarching objective is to automate the end-to-end IFRS 9 credit risk pipeline, from raw data ingestion to interactive executive reporting.

Specific objectives include:

- **O1 – Extraction & Ingestion:** automate loan data extraction from SQL Server and macroeconomic time-series ingestion from FRED into Databricks.
- **O2 – Data Preparation & Quality:** cleanse, cast, and filter 100% of raw records (null handling, anomaly removal, 2018 cohort scope).
- **O3 – Star Schema Modeling:** structure a reliable analytical data warehouse around a central fact table (`fact_metrics`) and 11 dimension tables.
- **O4 – Quantitative Modeling (PD / ECL):** train and compare Probability of Default models (*LR Retail* vs. *LR Retail + Macro*) and compute Expected Credit Losses (ECL).
- **O5 – Forward-Looking Stress Testing:** simulate the impact of macroeconomic scenarios (*Baseline*, *Adverse*, *Severe*) on ECL and capital consumption.
- **O6 – Reporting:** deliver 100% of prudential and model validation KPIs in a multi-page interactive Power BI dashboard.

## 3. Functional Scope and Process

The pipeline covers six main stages:

1. **Source Data Extraction:** exporting loan data from SQL Server (`sqlcmd`) into a Databricks volume.
2. **Data Cleansing & Preparation:** casting data types, handling missing values, filtering the study scope (2018 issuance), and generating unique identifiers using SHA-256 hashing.
3. **Macroeconomic Enrichment:** ingesting key economic indicators via Python API (`pandas_datareader` / FRED)—unemployment rate, Consumer Price Index (`cpi_index`), Fed Funds interest rate, and GDP—with time-series smoothing.
4. **Analytical Modeling (Star Schema):** building dimension tables (`dim_client`, `dim_product`, `dim_rating`, `dim_risk`, `dim_macro`, etc.) and the central `fact_metrics` table on Delta Lake.
5. **Credit Risk Modeling (IFRS 9):** classifying loans into IFRS 9 Stages (1, 2, 3), training logistic regression PD models, computing validation metrics (AUC, Gini, KS, PSI/CSI, SHAP), and running macro stress simulations.
6. **Business Intelligence Reporting:** designing an interactive Power BI report structured across 5 executive and analytical views.

## 4. Key Performance Indicators (KPIs)

The indicators monitored across the dashboards include:

| KPI | Definition / Calculation Rule | Value / Target |
|---|---|---:|
| Total RWA | Sum of Risk-Weighted Assets | \$317.04M |
| RWA Density | Total RWA / Total EAD × 100 | 69.65% |
| CET1 Ratio | Common Equity Tier 1 Capital / Total RWA × 100 | 17.23% (Target ≥ 10.5%) |
| Capital Requirement | Total RWA × 8% (Basel III minimum requirement) | \$25.36M |
| Total EAD | Total Exposure at Default (`out_prncp`) | \$455.18M |
| Total ECL | Expected Credit Loss (`PD × LGD × EAD`) | \$8.12M |
| Cost of Risk | Total ECL / Total EAD × 100 | 1.78% |
| Coverage Ratio | ECL Provisions / Defaulted Exposure (Stage 3) × 100 | 74.98% |
| Discriminatory Power (AUC / Gini) | Area Under ROC Curve / `2 × AUC − 1` | 0.772 / 54.34% (Target AUC > 0.75) |
| Model Stability (PSI) | Population Stability Index across samples | 0.00063 (Target < 0.10) |

## 5. Data Architecture and Sources

### Data Sources

| Source | Description | Access |
|---|---|---|
| SQL Server (`Risk_Basel3`) | Relational database containing raw loan portfolio records (`dbo.Loan_Databricks`) | CSV export via `sqlcmd` |
| FRED API (Federal Reserve) | Macroeconomic time series (`UNRATE`, `CPIAUCSL`, `FEDFUNDS`, `GDP`) | Python ingestion (`pandas_datareader`) |
| Databricks Delta Lake | Centralized analytical warehouse (Star Schema `IFRS_9_credit_risk`) | SQL & PySpark Read/Write |

### Data Quality

Data quality controls cover six core dimensions:

- **Completeness:** filtering out records missing job titles (`emp_title`), employment length (`n/a`), or verification status, and forward-filling missing GDP values.
- **Accuracy:** strict numeric type casting (replacing commas with decimal points) and date standardization (`issue_d`, `last_pymnt_d`).
- **Consistency:** temporal alignment between loan origination dates and monthly macroeconomic indicators.
- **Uniqueness:** deterministic surrogate key generation using `SHA-256` hashing and `DENSE_RANK()` across all dimensions.
- **Timeliness:** orchestrated updates via Databricks pipelines and Delta table refreshes.
- **Traceability:** retention of intermediate staging versions (`loan_v0`, `loan_vs`, `loan_v1`, `dim_macro_v0`) for full transformation auditability.

## 6. Business Rules

| ID | Rule | Description | Status |
|---|---|---|---|
| RG-PER-001 | Study Scope | Only loans issued in **2018** with a credit history starting between **2010 and 2015** and a verified income status are retained. | Validated |
| RG-STG-001 | IFRS 9 Staging Classification | **Stage 3**: defaulted loans (`Charged Off`, `Default`); **Stage 2**: delinquent loans (`Late`); **Stage 1**: performing loans (`Current`, `Fully Paid`). | Validated |
| RG-CAL-001 | EAD & Loss Calculation | Exposure at Default (`EAD`) equals remaining principal (`out_prncp`); realized loss equals `funded_amnt − total_rec_prncp`. | Validated |
| RG-MAC-001 | Macroeconomic Processing | Application of a *Forward-Fill* (`LAST_VALUE`) on quarterly GDP to match monthly granularity, plus a 2-month rolling average. | Validated |
| RG-MOD-001 | PD Model Evaluation | Systematic benchmarking between the baseline model (*LR Retail*) and forward-looking model (*LR Retail + Macro*) using AUC, KS, Brier Score, and PSI/CSI. | Validated |
| RG-STR-001 | Forward-Looking Scenarios | Weighting and simulation of Expected Credit Losses (ECL) across three economic scenarios: *Baseline*, *Adverse*, and *Severe* (+50% PD/ECL shock). | Validated |
| RG-SEC-001 | Pseudonymization | Replacement of direct borrower attributes with a hashed key (`member_hash`) and sequential technical ID (`member_id`). | Validated |

## 7. Project Value Added

This framework provides a complete Data & Risk architecture alongside interactive dashboards enabling stakeholders to:

- Monitor Basel III / IFRS 9 prudential metrics (RWA, CET1, capital requirements, cost of risk).
- Track exposure distribution and credit quality migration across **Stages 1, 2, and 3**.
- Analyze portfolio sensitivity by internal credit grade (`A` to `G`), loan purpose, and US geographical state.
- Quantify the predictive uplift of macroeconomic variables (inflation, unemployment, interest rates, GDP) on default rates.
- Interpret model predictions using feature importance and **SHAP** values.
- Assess the impact of adverse economic shocks (*Stress Testing*) on ECL provisions and capital consumption.

---

**Project:** IFRS 9 Forward-Looking Credit Risk Analytics  
**Tech Stack:** SQL Server, Databricks (PySpark / Delta Lake), Python (FRED API), Microsoft Power BI

