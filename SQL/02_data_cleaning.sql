-- ============================================================================
-- PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
-- SCRIPT      : 03_star_schema_creation.sql (Partie 1/2)
-- DESCRIPTION : Sélection des variables métier clés (loan_v1), génération des 
--               identifiants séquentiels et construction des premières tables 
--               de dimensions (dim_client, dim_product, dim_date, dim_risk).
-- ============================================================================


-- ============================================================================
-- 1. PRÉPARATION DE LA TABLE DE TRAVAIL CENTRALE (LOAN_V1)
-- ============================================================================

-- 1.1 Sélection des attributs financiers et de risque retenus pour le projet
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

-- 1.2 Génération d'un identifiant technique incrémental unique par prêt (id)
REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    ROW_NUMBER() OVER (ORDER BY monotonically_increasing_id()) AS id,
    *
EXCEPT(id)
FROM IFRS_9_credit_risk.loan_v1;


-- ============================================================================
-- 2. DIMENSION CLIENT (DIM_CLIENT) – PSEUDONYMISATION & DÉDOUBLONNAGE
-- ============================================================================

-- 2.1 Génération de la clé de hachage SHA-256 et de l'ID client dans loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
WITH base AS (
    SELECT
        l.* EXCEPT(member_id),
        -- Création de l'empreinte cryptographique client (SHA-256)
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
        -- Attribution d'un identifiant numérique séquentiel par profil unique
        DENSE_RANK() OVER (ORDER BY member_hash) AS member_id
    FROM base
)
SELECT *
FROM final;

-- 2.2 Création de la table de dimension dim_client
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


-- ============================================================================
-- 3. DIMENSION PRODUIT FINANCIER (DIM_PRODUCT)
-- ============================================================================

-- 3.1 Génération de la clé technique product_hash dans loan_v1
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

-- 3.2 Création de la table de dimension dim_product
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

-- 3.3 Rattachement de la clé étrangère product_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    d.product_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_product d
ON l.product_hash = d.product_hash;


-- ============================================================================
-- 4. DIMENSION CALENDRIER (DIM_DATE) & NORMALISATION DES DATES
-- ============================================================================

-- 4.1 Génération du référentiel calendaire continu (2007 à 2025)
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

-- 4.2 Conversion et nettoyage des dates métier dans loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    -- Normalisation de la date d'octroi
    TRY_TO_DATE(CONCAT('01-', issue_d), 'dd-MMM-yy') AS issue_d_clean,
    -- Normalisation de la date du dernier paiement
    TRY_TO_DATE(CONCAT('01-', last_pymnt_d), 'dd-MMM-yy') AS last_pymnt_d_clean,
    -- Normalisation de la date de prochaine échéance
    TRY_TO_DATE(CONCAT('01-', next_pymnt_d), 'dd-MMM-yy') AS next_pymnt_d_clean
FROM IFRS_9_credit_risk.loan_v1 l;

-- 4.3 Association des clés étrangères temporelles (date_id)
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

-- 4.4 Gestion des valeurs nulles sur les clés temporelles (valeur par défaut : -1)
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT *,
    COALESCE(issue_date_id, -1) AS issue_date_id_final,
    COALESCE(last_payment_date_id, -1) AS last_payment_date_id_final,
    COALESCE(next_payment_date_id, -1) AS next_payment_date_id_final
FROM IFRS_9_credit_risk.loan_v1;


-- ============================================================================
-- 5. DIMENSION PROFIL DE RISQUE (DIM_RISK)
-- ============================================================================

-- 5.1 Génération de la clé de regroupement risque (risk_hash)
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
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

-- 5.2 Création de dim_risk avec segmentation métier (buckets DTI et utilisation)
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_risk AS
WITH base AS (
    SELECT DISTINCT
        risk_hash,
        upper(trim(coalesce(grade,''))) AS grade,
        upper(trim(coalesce(sub_grade,''))) AS sub_grade,
        -- Segmentation du ratio d'endettement (DTI)
        CASE 
            WHEN dti < 10 THEN 'LOW_DTI'
            WHEN dti BETWEEN 10 AND 20 THEN 'MEDIUM_DTI'
            ELSE 'HIGH_DTI'
        END AS dti_bucket,
        -- Segmentation du taux d'utilisation du crédit renouvelable
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

-- 5.3 Rattachement de la clé étrangère risk_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    r.risk_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_risk r
ON l.risk_hash = r.risk_hash;
