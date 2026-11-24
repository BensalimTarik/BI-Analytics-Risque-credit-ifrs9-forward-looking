-- Kepp just the most important columns for the projet

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    id,
    member_id,
    loan_amnt,
    funded_amnt,
    funded_amnt_inv,
    term,
    int_rate,
    installment,
    grade,
    sub_grade,
    emp_title,
    emp_length,
    home_ownership,
    annual_inc,
    verification_status,
    issue_d,
    loan_status,
    purpose,
    title,
    zip_code,
    addr_state,
    dti,
    delinq_2yrs,
    earliest_cr_line,
    inq_last_6mths,
    open_acc,
    pub_rec,
    revol_bal,
    revol_util,
    total_acc,
    out_prncp,
    out_prncp_inv,
    total_pymnt,
    total_pymnt_inv,
    total_rec_prncp,
    total_rec_int,
    total_rec_late_fee,
    recoveries,
    collection_recovery_fee,
    last_pymnt_d,
    last_pymnt_amnt,
    next_pymnt_d,
    last_credit_pull_d,
    application_type,
    acc_now_delinq,
    tot_cur_bal,
    total_bal_il,
    total_rev_hi_lim,
    acc_open_past_24mths,
    avg_cur_bal,
    bc_util,
    mort_acc,
    num_actv_bc_tl,
    num_actv_rev_tl,
    num_bc_tl,
    num_rev_accts,
    pct_tl_nvr_dlq,
    percent_bc_gt_75,
    pub_rec_bankruptcies,
    tax_liens,
    tot_hi_cred_lim,
    total_bal_ex_mort,
    total_bc_limit,
    total_il_high_credit_limit,
    hardship_flag,
    debt_settlement_flag
FROM IFRS_9_credit_risk.loan_v0;

-- Add incremental numerical identifiant for id

REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    ROW_NUMBER() OVER (ORDER BY monotonically_increasing_id()) AS id,
    *
EXCEPT(id)
FROM IFRS_9_credit_risk.loan_v1;


-- Create Has Code and Id for Client in loan
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
WITH base AS (
    SELECT
        l.* EXCEPT(member_id),
        -- 1. Création du HASH client
        sha2(
            concat_ws(
                '||',
                upper(trim(coalesce(emp_title,''))),
                coalesce(cast(annual_inc AS STRING),'0'),
                upper(trim(coalesce(zip_code,''))),
                upper(trim(coalesce(addr_state,''))),
                upper(trim(coalesce(home_ownership,''))),
                coalesce(earliest_cr_line,''),
                upper(trim(coalesce(emp_length,''))),
                upper(trim(coalesce(verification_status,'')))
            ),
            256
        ) AS member_hash
    FROM IFRS_9_credit_risk.loan_v1 l
),
final AS (
    SELECT
        *,
        -- 2. ID numérique client
        DENSE_RANK() OVER (ORDER BY member_hash) AS member_id
    FROM base
)
SELECT *
FROM final;

-- Dim client creation 
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_client AS
WITH base AS (
    SELECT DISTINCT
        emp_title,
        annual_inc,
        zip_code,
        addr_state,
        home_ownership,
        earliest_cr_line,
        emp_length,
        verification_status,
        member_hash
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY member_hash) AS member_id,
    emp_title,
    annual_inc,
    zip_code,
    addr_state,
    home_ownership,
    earliest_cr_line,
    emp_length,
    verification_status,
    member_hash
FROM base;

----------------------------------------------------------------------------------------------------
-- dim_product
-- Create product_hash in loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    sha2(
        concat_ws(
            '||',
            upper(trim(coalesce(purpose,''))),
            coalesce(term,''),
            upper(trim(coalesce(grade,''))),
            upper(trim(coalesce(sub_grade,'')))
        ),
        256
    ) AS product_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- dim_product creation 
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_product AS
WITH base AS (
    SELECT DISTINCT
        purpose,
        term,
        grade,
        sub_grade,
        product_hash
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY product_hash) AS product_id,
    purpose,
    term,
    grade,
    sub_grade,
    product_hash
FROM base;

-- link product_id to loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    d.product_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_product d
ON l.product_hash = d.product_hash;

--------------------------------------------------------------------------------------------------
-- dim_dates
-- dim_date creation
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_date AS
WITH calendar AS (
    SELECT explode(
        sequence(
            to_date('2007-01-01'),
            to_date('2025-12-31'),
            interval 1 day
        )
    ) AS full_date
)
SELECT
    ROW_NUMBER() OVER (ORDER BY full_date) AS date_id,
    full_date,
    YEAR(full_date) AS year,
    QUARTER(full_date) AS quarter,
    MONTH(full_date) AS month,
    DATE_FORMAT(full_date, 'MMMM') AS month_name,
    DAY(full_date) AS day,
    WEEKOFYEAR(full_date) AS week
FROM calendar;

-- Dates cleaning and creation in loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    -- CLEAN ISSUE DATE
    TRY_TO_DATE(CONCAT('01-', issue_d), 'dd-MMM-yy') AS issue_d_clean,
    -- CLEAN LAST PAYMENT
    TRY_TO_DATE(CONCAT('01-', last_pymnt_d), 'dd-MMM-yy') AS last_pymnt_d_clean,
    -- CLEAN NEXT PAYMENT
    TRY_TO_DATE(CONCAT('01-', next_pymnt_d), 'dd-MMM-yy') AS next_pymnt_d_clean
FROM IFRS_9_credit_risk.loan_v1 l;

--  IDS dates add 
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    d1.date_id AS issue_date_id,
    d2.date_id AS last_payment_date_id,
    d3.date_id AS next_payment_date_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_date d1
ON l.issue_d_clean = d1.full_date

LEFT JOIN IFRS_9_credit_risk.dim_date d2
ON l.last_pymnt_d_clean = d2.full_date

LEFT JOIN IFRS_9_credit_risk.dim_date d3
ON l.next_pymnt_d_clean = d3.full_date;

-- Nulls management
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT *,
    COALESCE(issue_date_id, -1) AS issue_date_id_final,
    COALESCE(last_payment_date_id, -1) AS last_payment_date_id_final,
    COALESCE(next_payment_date_id, -1) AS next_payment_date_id_final
FROM IFRS_9_credit_risk.loan_v1;

-------------------------------------------------------------------------------------------------------
-- dim_risk

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    -- RISK HASH (clé de regroupement risque)
    sha2(
        concat_ws(
            '||',
            upper(trim(coalesce(grade,''))),
            upper(trim(coalesce(sub_grade,''))),
            coalesce(cast(dti AS STRING),'0'),
            coalesce(cast(revol_util AS STRING),'0'),
            coalesce(cast(delinq_2yrs AS STRING),'0'),
            coalesce(cast(pub_rec AS STRING),'0'),
            coalesce(cast(inq_last_6mths AS STRING),'0')
        ),
        256
    ) AS risk_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- dim_risk creation

CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_risk AS
WITH base AS (
    SELECT DISTINCT
        risk_hash,
        upper(trim(coalesce(grade,''))) AS grade,
        upper(trim(coalesce(sub_grade,''))) AS sub_grade,
        -- segmentation risque (features importantes PD)
        CASE 
            WHEN dti < 10 THEN 'LOW_DTI'
            WHEN dti BETWEEN 10 AND 20 THEN 'MEDIUM_DTI'
            ELSE 'HIGH_DTI'
        END AS dti_bucket,
        CASE 
            WHEN revol_util < 30 THEN 'LOW_UTIL'
            WHEN revol_util BETWEEN 30 AND 70 THEN 'MEDIUM_UTIL'
            ELSE 'HIGH_UTIL'
        END AS revol_util_bucket,
        coalesce(delinq_2yrs,0) AS delinq_2yrs,
        coalesce(pub_rec,0) AS pub_rec,
        coalesce(inq_last_6mths,0) AS inq_last_6mths

    FROM IFRS_9_credit_risk.loan_v1
)

SELECT
    DENSE_RANK() OVER (ORDER BY risk_hash) AS risk_id,
    grade,
    sub_grade,
    dti_bucket,
    revol_util_bucket,
    delinq_2yrs,
    pub_rec,
    inq_last_6mths,
    risk_hash
FROM base;

-- link dim_risk to loan_v1 
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    r.risk_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_risk r
ON l.risk_hash = r.risk_hash;

------------------------------------------------------------------------------------------------------
-- dim_geography
-- Hash code geography_hash creation
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    sha2(
        concat_ws(
            '||',
            upper(trim(coalesce(l.addr_state,''))),
            upper(trim(coalesce(l.zip_code,'')))
        ),
        256
    ) AS geography_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- dim_geography creation
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_geography AS
WITH base AS (
    SELECT DISTINCT
        geography_hash,
        upper(trim(addr_state)) AS state,
        zip_code,
        -- REGION MAPPING (US standard bancaire simplifié)
        CASE 
            WHEN addr_state IN ('CA','WA','OR','NV','AZ') THEN 'WEST'
            WHEN addr_state IN ('NY','NJ','MA','PA','CT','RI','VT','NH','ME') THEN 'EAST'
            WHEN addr_state IN ('TX','FL','GA','NC','SC','AL','MS','LA','TN','KY','AR','OK','VA','WV','DE','MD','DC') THEN 'SOUTH'
            ELSE 'MIDWEST'
        END AS region,
        -- URBAN / RURAL PROXY (heuristique zip)
        CASE 
            WHEN CAST(SUBSTRING(zip_code,1,2) AS INT) BETWEEN 10 AND 69 THEN 'URBAN'
            WHEN CAST(SUBSTRING(zip_code,1,2) AS INT) BETWEEN 70 AND 89 THEN 'SUBURBAN'
            ELSE 'RURAL'
        END AS urban_rural_proxy
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY geography_hash) AS geography_id,
    *,
    -- RISK SCORE SIMPLE (peut être enrichi ML plus tard)
    CASE region
        WHEN 'WEST' THEN 0.7
        WHEN 'EAST' THEN 0.6
        WHEN 'SOUTH' THEN 0.9
        ELSE 0.5
    END AS risk_region_score
FROM base;

-- LINK dim_geography to loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    g.geography_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_geography g
ON l.geography_hash = g.geography_hash;

--------------------------------------------------------------------------------------------------------------------
-- dim_employment
-- Add employment_hash in loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    sha2(
        concat_ws(
            '||',
            upper(trim(coalesce(emp_title,''))),
            upper(trim(coalesce(emp_length,''))),
            upper(trim(coalesce(verification_status,'')))
        ),
        256
    ) AS employment_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- Create dim_employment
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_employment AS
WITH base AS (
    SELECT DISTINCT
        employment_hash,
        emp_title,
        emp_length,
        verification_status,
        CASE 
            WHEN emp_length IN ('< 1 year','1 year','2 years') THEN 'LOW_STABILITY'
            WHEN emp_length IN ('3 years','4 years','5 years') THEN 'MEDIUM_STABILITY'
            ELSE 'HIGH_STABILITY'
        END AS employment_stability_bucket
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY employment_hash) AS employment_id,
    employment_hash,
    emp_title,
    emp_length,
    verification_status,
    employment_stability_bucket
FROM base;

-- Link dim_employment to loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    e.employment_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_employment e
ON l.employment_hash = e.employment_hash;

----------------------------------------------------------------------------------------------------------------
-- dim_loan_status to identify each loan status

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    sha2(
        concat_ws('||', upper(trim(coalesce(loan_status,'')))),
        256
    ) AS loan_status_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- dim_loan_status creation - IFRS 9 classification + default flag

CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_loan_status AS
WITH base AS (

    SELECT DISTINCT
        loan_status_hash,
        loan_status,

        CASE 
            WHEN loan_status IN ('Fully Paid') THEN 'PERFORMING'
            WHEN loan_status IN ('Current') THEN 'ACTIVE'
            WHEN loan_status IN ('Charged Off','Default') THEN 'DEFAULT'
            ELSE 'DELINQUENT'
        END AS status_category,

        CASE 
            WHEN loan_status IN ('Charged Off','Default') THEN 1 ELSE 0
        END AS default_flag

    FROM IFRS_9_credit_risk.loan_v1
)

SELECT
    DENSE_RANK() OVER (ORDER BY loan_status_hash) AS loan_status_id,
    *
FROM base;

-- Link dim_loan_status to FACT (loan_v1 enrichment)

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    s.loan_status_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_loan_status s
ON l.loan_status_hash = s.loan_status_hash;

---------------------------------------------------------------------------------------------------
-- dim_rating
-- Create a stable technical key (grade + sub-grade) | Used to link FACT ↔ DIM | Guarantees uniqueness of the risk profile

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    sha2(
        concat_ws('||',
            upper(trim(coalesce(grade,''))),
            upper(trim(coalesce(sub_grade,'')))
        ),
        256
    ) AS rating_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- Create dim_rating | Transform raw rating into bank risk | Used for PD modeling / IFRS 9 staging / pricing

CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_rating AS
WITH base AS (
    SELECT DISTINCT
        rating_hash,
        -- attributs crédit
        upper(trim(grade)) AS grade,
        upper(trim(sub_grade)) AS sub_grade,
        -- score réglementaire (Basel III IRB logic)
        CASE upper(trim(grade))
            WHEN 'A' THEN 1
            WHEN 'B' THEN 2
            WHEN 'C' THEN 3
            WHEN 'D' THEN 4
            WHEN 'E' THEN 5
            WHEN 'F' THEN 6
            WHEN 'G' THEN 7
            ELSE 99
        END AS rating_score,
        -- segmentation business / IFRS 9
        CASE upper(trim(grade))
            WHEN 'A' THEN 'LOW_RISK'
            WHEN 'B' THEN 'LOW_MEDIUM'
            WHEN 'C' THEN 'MEDIUM'
            WHEN 'D' THEN 'HIGH'
            WHEN 'E' THEN 'VERY_HIGH'
            ELSE 'DEFAULT_RISK'
        END AS risk_bucket,
        -- staging IFRS 9
        CASE upper(trim(grade))
            WHEN 'A' THEN 1
            WHEN 'B' THEN 1
            WHEN 'C' THEN 2
            WHEN 'D' THEN 2
            ELSE 3
        END AS stage_suggestion
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY rating_hash) AS rating_id,
    -- ❗ important : on enlève rating_hash du * pour éviter duplication
    * EXCEPT (rating_hash),
    rating_hash
FROM base;

-- Link dim_rating to loan_v1

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    r.rating_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_rating r
ON l.rating_hash = r.rating_hash;

---------------------------------------------------------------------------------------------------------------
-- dim_behavior (customer behavior) | create a customer behavior key | credit usage + revolving activity | used for PD early warning -- segmentation
-- Create behavior hash in fact table

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,

    sha2(
        concat_ws('||',
            coalesce(cast(revol_bal AS STRING),'0'),
            coalesce(cast(revol_util AS STRING),'0'),
            coalesce(cast(total_acc AS STRING),'0'),
            coalesce(cast(open_acc AS STRING),'0'),
            coalesce(cast(acc_open_past_24mths AS STRING),'0')
        ),
        256
    ) AS behavior_hash

FROM IFRS_9_credit_risk.loan_v1 l;

-- Create dim_behavior | transform credit behavior into risk segments | used for early warning IFRS9 Stage 2

CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_behavior AS
WITH base AS (
    SELECT DISTINCT
        behavior_hash,
        revol_bal,
        revol_util,
        total_acc,
        open_acc,
        acc_open_past_24mths
    FROM IFRS_9_credit_risk.loan_v1
)
SELECT
    DENSE_RANK() OVER (ORDER BY behavior_hash) AS behavior_id,
    * EXCEPT (behavior_hash),
    behavior_hash
FROM base;

-- Link  dim_behavior to fact

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    b.behavior_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_behavior b
ON l.behavior_hash = b.behavior_hash;

-------------------------------------------------------------------------------------------------------------------------------
-- dim_credit_history | Analyze historical customer credit depth | age + historical behavior | Used for PD / IFRS 9 / scoring
-- Create hash code

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,

    sha2(
        concat_ws('||',
            coalesce(earliest_cr_line,''),
            coalesce(cast(total_acc AS STRING),'0'),
            coalesce(cast(open_acc AS STRING),'0'),
            coalesce(cast(pub_rec AS STRING),'0'),
            coalesce(cast(pub_rec_bankruptcies AS STRING),'0')
        ),
        256
    ) AS credit_history_hash
FROM IFRS_9_credit_risk.loan_v1 l;

-- dim_credit_history creation

CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_credit_history AS

WITH base AS (
    SELECT DISTINCT
        credit_history_hash,

        earliest_cr_line,
        total_acc,
        open_acc,
        pub_rec,
        pub_rec_bankruptcies,

        -- ancienneté crédit (feature clé risque)
        CASE 
            WHEN total_acc < 10 THEN 'NEW_HISTORY'
            WHEN total_acc BETWEEN 10 AND 25 THEN 'MID_HISTORY'
            ELSE 'LONG_HISTORY'
        END AS credit_depth_bucket,

        -- qualité historique
        CASE 
            WHEN pub_rec_bankruptcies > 0 THEN 'BAD_HISTORY'
            WHEN pub_rec > 0 THEN 'MEDIUM_RISK_HISTORY'
            ELSE 'CLEAN_HISTORY'
        END AS credit_quality_bucket

    FROM IFRS_9_credit_risk.loan_v1
)

SELECT
    DENSE_RANK() OVER (ORDER BY credit_history_hash) AS credit_history_id,
    * EXCEPT (credit_history_hash),
    credit_history_hash
FROM base;

-- link dim_credit_history to fact
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS

SELECT
    l.*,
    c.credit_history_id

FROM IFRS_9_credit_risk.loan_v1 l

LEFT JOIN IFRS_9_credit_risk.dim_credit_history c
ON l.credit_history_hash = c.credit_history_hash;

---------------------------------------------------------------------------------------------------
-- Create fact_metrics
-- =========================================
-- FACT_METRICS
-- TABLE CENTRALE IFRS9 / RISK ANALYTICS
-- Grain = 1 prêt
-- =========================================

CREATE OR REPLACE TABLE IFRS_9_credit_risk.fact_metrics AS

SELECT

    -- =====================================
    -- PRIMARY KEY FACT
    -- =====================================
    l.id AS loan_id,

    -- =====================================
    -- DIMENSION KEYS
    -- =====================================
    l.member_id,
    l.product_id,
    l.rating_id,
    l.risk_id,
    l.behavior_id,
    l.credit_history_id,
    l.employment_id,
    l.geography_id,
    l.loan_status_id,

    -- =====================================
    -- DATE DIMENSION KEYS
    -- =====================================
    issue_dim.date_id       AS issue_date_id,
    last_dim.date_id        AS last_payment_date_id,
    next_dim.date_id        AS next_payment_date_id,

    -- =====================================
    -- RAW DATES
    -- =====================================
    l.issue_d,
    l.last_pymnt_d,
    l.next_pymnt_d,

    -- =====================================
    -- FINANCIAL MEASURES
    -- =====================================
    l.loan_amnt,
    l.funded_amnt,
    l.funded_amnt_inv,

    l.installment,
    l.int_rate,

    l.out_prncp,
    l.out_prncp_inv,

    l.total_pymnt,
    l.total_pymnt_inv,

    l.total_rec_prncp,
    l.total_rec_int,
    l.total_rec_late_fee,

    l.recoveries,
    l.collection_recovery_fee,

    l.last_pymnt_amnt,

    -- =====================================
    -- CLIENT FINANCIAL PROFILE
    -- =====================================
    l.annual_inc,
    l.dti,

    l.revol_bal,
    l.revol_util,

    l.total_acc,
    l.open_acc,

    l.total_bal_il,
    l.total_rev_hi_lim,

    l.bc_util,

    -- =====================================
    -- IFRS9 KPI
    -- =====================================

    -- Exposure At Default
    coalesce(l.out_prncp,0) AS exposure_at_default,

    -- Loss Amount
    (
        coalesce(l.funded_amnt,0)
        - coalesce(l.total_rec_prncp,0)
    ) AS loss_amount,

    -- Recovery Rate
    CASE
        WHEN l.funded_amnt > 0 THEN
            l.recoveries / l.funded_amnt
        ELSE 0
    END AS recovery_rate,

    -- Utilization Rate
    CASE
        WHEN l.total_rev_hi_lim > 0 THEN
            l.revol_bal / l.total_rev_hi_lim
        ELSE 0
    END AS utilization_rate,

    -- Credit Age (months)
    CASE
        WHEN l.earliest_cr_line IS NOT NULL THEN
            months_between(
                to_date(concat('01-', l.issue_d), 'dd-MMM-yy'),
                to_date(concat('01-', l.earliest_cr_line), 'dd-MMM-yy')
            )
        ELSE NULL
    END AS credit_age_months,

    -- =====================================
    -- DEFAULT FLAG
    -- =====================================
    CASE
        WHEN lower(l.loan_status) IN (
            'charged off',
            'default',
            'late (31-120 days)'
        )
        THEN 1
        ELSE 0
    END AS default_flag,

    -- =====================================
    -- IFRS9 STAGING
    -- =====================================
    CASE
        WHEN lower(l.loan_status) IN (
            'charged off',
            'default'
        )
        THEN 3

        WHEN lower(l.loan_status) LIKE '%late%'
        THEN 2

        ELSE 1
    END AS ifrs9_stage

FROM IFRS_9_credit_risk.loan_v1 l

-- =========================================
-- LINK ISSUE DATE
-- =========================================
LEFT JOIN IFRS_9_credit_risk.dim_date issue_dim
ON to_date(concat('01-', l.issue_d), 'dd-MMM-yy')
    = issue_dim.full_date

-- =========================================
-- LINK LAST PAYMENT DATE
-- =========================================
LEFT JOIN IFRS_9_credit_risk.dim_date last_dim
ON to_date(concat('01-', l.last_pymnt_d), 'dd-MMM-yy')
    = last_dim.full_date

-- =========================================
-- LINK NEXT PAYMENT DATE
-- =========================================
LEFT JOIN IFRS_9_credit_risk.dim_date next_dim
ON to_date(concat('01-', l.next_pymnt_d), 'dd-MMM-yy')
    = next_dim.full_date;


---------------------------------------------------------------------------------------------------
-- Somme SQL queries | Tables listing

select * from IFRS_9_credit_risk.loan_v1  LIMIT 10;
select * from IFRS_9_credit_risk.fact_metrics  LIMIT 10;
select * from IFRS_9_credit_risk.dim_client LIMIT 10;

select count(*) from IFRS_9_credit_risk.dim_client

select * from IFRS_9_credit_risk.dim_product LIMIT 10;
select * from IFRS_9_credit_risk.dim_date LIMIT 10;
select * from IFRS_9_credit_risk.dim_risk LIMIT 10;
select * from IFRS_9_credit_risk.dim_geography LIMIT 10;
select * from IFRS_9_credit_risk.dim_employment LIMIT 10;
select * from IFRS_9_credit_risk.dim_loan_status LIMIT 10;
select * from IFRS_9_credit_risk.dim_rating LIMIT 10;
select *  from IFRS_9_credit_risk.dim_behavior LIMIT 10;
select * from IFRS_9_credit_risk.dim_credit_history LIMIT 10;
select * from IFRS_9_credit_risk.dim_macro LIMIT 10;
