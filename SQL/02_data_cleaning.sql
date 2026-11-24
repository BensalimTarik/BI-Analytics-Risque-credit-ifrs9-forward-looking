-- ============================================================================
-- PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
-- SCRIPT      : 03_star_schema_creation.sql
-- DESCRIPTION : Construction complète du modèle dimensionnel en étoile 
--               (Star Schema) sous Delta Lake :
--               - Sélection des variables clés (loan_v1)
--               - Création de 10 dimensions métier avec hachage SHA-256
--               - Construction de la table de faits centrale (fact_metrics)
--               - Requêtes de contrôle et d'audit de volumétrie
-- ============================================================================


-- ============================================================================
-- 1. PRÉPARATION DE LA TABLE DE TRAVAIL CENTRALE (LOAN_V1)
-- ============================================================================

-- 1.1 Sélection des variables métier et de risque retenues pour le projet
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

-- 2.1 Création de l'empreinte SHA-256 et de l'ID client dans loan_v1
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

-- 4.2 Nettoyage et conversion des dates métier dans loan_v1
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

-- 4.4 Gestion des valeurs nulles sur les clés temporelles (-1 par défaut)
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

-- 5.2 Création de dim_risk avec segmentation métier (buckets DTI & utilisation)
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

-- 5.3 Rattachement de la clé étrangère risk_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
    l.*,
    r.risk_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_risk r
ON l.risk_hash = r.risk_hash;
-- ============================================================================
-- 6. DIMENSION GÉOGRAPHIQUE (DIM_GEOGRAPHY)
-- ============================================================================
-- 6.1 Génération de la clé géographique geography_hash dans loan_v1
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
-- 6.2 Création de dim_geography avec découpage régional et score de risque
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
-- 6.3 Rattachement de la clé étrangère geography_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
g.geography_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_geography g
ON l.geography_hash = g.geography_hash;
-- ============================================================================
-- 7. DIMENSION STABILITÉ PROFESSIONNELLE (DIM_EMPLOYMENT)
-- ============================================================================
-- 7.1 Génération de la clé employment_hash dans loan_v1
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
-- 7.2 Création de dim_employment avec classification de stabilité d'emploi
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
-- 7.3 Rattachement de la clé étrangère employment_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
e.employment_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_employment e
ON l.employment_hash = e.employment_hash;
-- ============================================================================
-- 8. DIMENSION STATUT DU PRÊT & DÉFAUT (DIM_LOAN_STATUS)
-- ============================================================================
-- 8.1 Génération de la clé loan_status_hash dans loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
sha2(
concat_ws('||', upper(trim(coalesce(loan_status,'')))),
256
) AS loan_status_hash
FROM IFRS_9_credit_risk.loan_v1 l;
-- 8.2 Création de dim_loan_status avec indicateur de défaut (default_flag)
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
-- 8.3 Rattachement de la clé étrangère loan_status_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
s.loan_status_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_loan_status s
ON l.loan_status_hash = s.loan_status_hash;
-- ============================================================================
-- 9. DIMENSION NOTATION INTERNE & STAGING (DIM_RATING)
-- ============================================================================
-- 9.1 Génération de la clé rating_hash (Grade + Sub-grade) dans loan_v1
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
-- 9.2 Création de dim_rating (Score IRB Bâle III et suggestion de Stage IFRS 9)
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
-- 9.3 Rattachement de la clé étrangère rating_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
r.rating_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_rating r
ON l.rating_hash = r.rating_hash;
-- ============================================================================
-- 10. DIMENSION COMPORTEMENT CRÉDIT (DIM_BEHAVIOR)
-- ============================================================================
-- 10.1 Génération de la clé behavior_hash dans loan_v1
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
-- 10.2 Création de dim_behavior (détection avancée Stage 2 IFRS 9)
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
-- 10.3 Rattachement de la clé étrangère behavior_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
b.behavior_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_behavior b
ON l.behavior_hash = b.behavior_hash;
-- ============================================================================
-- 11. DIMENSION HISTORIQUE DE CRÉDIT (DIM_CREDIT_HISTORY)
-- ============================================================================
-- 11.1 Génération de la clé credit_history_hash dans loan_v1
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
-- 11.2 Création de dim_credit_history (profondeur et qualité de l'historique)
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
-- 11.3 Rattachement de la clé étrangère credit_history_id à loan_v1
CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v1 AS
SELECT
l.*,
c.credit_history_id
FROM IFRS_9_credit_risk.loan_v1 l
LEFT JOIN IFRS_9_credit_risk.dim_credit_history c
ON l.credit_history_hash = c.credit_history_hash;
-- ============================================================================
-- 12. TABLE DE FAITS CENTRALE IFRS 9 (FACT_METRICS)
-- ============================================================================
-- Granularité : 1 ligne par contrat de prêt (loan_id)
CREATE OR REPLACE TABLE IFRS_9_credit_risk.fact_metrics AS
SELECT
-- ------------------------------------------------------------------------
-- 12.1 Clé primaire de la table de faits
-- ------------------------------------------------------------------------
l.id AS loan_id,
-- ------------------------------------------------------------------------
-- 12.2 Clés étrangères vers les dimensions métier
-- ------------------------------------------------------------------------
l.member_id,
l.product_id,
l.rating_id,
l.risk_id,
l.behavior_id,
l.credit_history_id,
l.employment_id,
l.geography_id,
l.loan_status_id,
-- ------------------------------------------------------------------------
-- 12.3 Clés étrangères vers la dimension calendrier (dim_date)
-- ------------------------------------------------------------------------
issue_dim.date_id       AS issue_date_id,
last_dim.date_id        AS last_payment_date_id,
next_dim.date_id        AS next_payment_date_id,
-- ------------------------------------------------------------------------
-- 12.4 Dates brutes de référence
-- ------------------------------------------------------------------------
l.issue_d,
l.last_pymnt_d,
l.next_pymnt_d,
-- ------------------------------------------------------------------------
-- 12.5 Mesures financières et flux de remboursement
-- ------------------------------------------------------------------------
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
-- ------------------------------------------------------------------------
-- 12.6 Profil financier et encours de l'emprunteur
-- ------------------------------------------------------------------------
l.annual_inc,
l.dti,
l.revol_bal,
l.revol_util,
l.total_acc,
l.open_acc,
l.total_bal_il,
l.total_rev_hi_lim,
l.bc_util,
-- ------------------------------------------------------------------------
-- 12.7 Indicateurs réglementaires IFRS 9 calculés (EAD, Pertes, Staging)
-- ------------------------------------------------------------------------
-- Exposure At Default (Exposition au défaut)
coalesce(l.out_prncp,0) AS exposure_at_default,
-- Loss Amount (Perte en capital constatée)
(
coalesce(l.funded_amnt,0)
- coalesce(l.total_rec_prncp,0)
) AS loss_amount,
-- Recovery Rate (Taux de recouvrement)
CASE
WHEN l.funded_amnt > 0 THEN
l.recoveries / l.funded_amnt
ELSE 0
END AS recovery_rate,
-- Utilization Rate (Taux d'utilisation des lignes renouvelables)
CASE
WHEN l.total_rev_hi_lim > 0 THEN
l.revol_bal / l.total_rev_hi_lim
ELSE 0
END AS utilization_rate,
-- Credit Age (Ancienneté du dossier de crédit en mois)
CASE
WHEN l.earliest_cr_line IS NOT NULL THEN
months_between(
to_date(concat('01-', l.issue_d), 'dd-MMM-yy'),
to_date(concat('01-', l.earliest_cr_line), 'dd-MMM-yy')
)
ELSE NULL
END AS credit_age_months,
-- Default Flag (Indicateur binaire de défaut)
CASE
WHEN lower(l.loan_status) IN (
'charged off',
'default',
'late (31-120 days)'
)
THEN 1
ELSE 0
END AS default_flag,
-- IFRS 9 Staging (Classification réglementaire Stage 1, 2, 3)
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
-- Jointure sur la date d'octroi
LEFT JOIN IFRS_9_credit_risk.dim_date issue_dim
ON to_date(concat('01-', l.issue_d), 'dd-MMM-yy')
= issue_dim.full_date
-- Jointure sur la date de dernier paiement
LEFT JOIN IFRS_9_credit_risk.dim_date last_dim
ON to_date(concat('01-', l.last_pymnt_d), 'dd-MMM-yy')
= last_dim.full_date
-- Jointure sur la date de prochaine échéance
LEFT JOIN IFRS_9_credit_risk.dim_date next_dim
ON to_date(concat('01-', l.next_pymnt_d), 'dd-MMM-yy')
= next_dim.full_date;

-- ============================================================================
-- 13. REQUÊTES DE CONTRÔLE ET VÉRIFICATION DES TABLES DU MODÈLE
-- ============================================================================
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
