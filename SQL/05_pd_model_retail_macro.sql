-- ============================================================================
-- PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
-- SCRIPT      : 05_pd_model_retail_macro.sql
-- DESCRIPTION : Préparation des datasets d'entraînement et de scoring pour les 
--               modèles de Probabilité de Défaut (PD) : modèle interne 
--               (model_retail) et modèle prospectif enrichi des variables 
--               macroéconomiques FRED (model_retail_macro) sur le périmètre 2018.
-- ============================================================================


-- ============================================================================
-- 1. DATASET DU MODÈLE DE BASE (MODEL_RETAIL – VARIABLES INTERNES)
-- ============================================================================
CREATE OR REPLACE TABLE IFRS_9_credit_risk.model_retail AS

SELECT
    -- ------------------------------------------------------------------------
    -- 1.1 Identifiant et variable cible (Target)
    -- ------------------------------------------------------------------------
    l.id AS loan_id,
    dls.default_flag,

    -- ------------------------------------------------------------------------
    -- 1.2 Profil socio-démographique et financier de l'emprunteur
    -- ------------------------------------------------------------------------
    l.annual_inc,
    l.home_ownership,
    l.emp_length,
    l.verification_status,
    l.addr_state,

    -- ------------------------------------------------------------------------
    -- 1.3 Caractéristiques du contrat de prêt et notation interne
    -- ------------------------------------------------------------------------
    l.loan_amnt,
    l.term,
    l.int_rate,
    l.installment,
    l.purpose,
    l.grade,
    l.sub_grade,

    -- ------------------------------------------------------------------------
    -- 1.4 Comportement de crédit et taux d'utilisation
    -- ------------------------------------------------------------------------
    l.dti,
    l.revol_util,
    l.bc_util,
    l.delinq_2yrs,
    l.inq_last_6mths,
    l.acc_now_delinq,

    -- ------------------------------------------------------------------------
    -- 1.5 Profondeur et incidents de l'historique de crédit
    -- ------------------------------------------------------------------------
    l.open_acc,
    l.total_acc,
    l.pub_rec,
    l.pub_rec_bankruptcies,
    l.tax_liens,

    -- ------------------------------------------------------------------------
    -- 1.6 Encours globaux, structure des comptes et qualité du portefeuille
    -- ------------------------------------------------------------------------
    l.tot_cur_bal,
    l.avg_cur_bal,
    l.mort_acc,
    l.num_actv_bc_tl,
    l.num_actv_rev_tl,
    l.num_bc_tl,
    l.num_rev_accts,
    l.pct_tl_nvr_dlq,
    l.percent_bc_gt_75,

    -- ------------------------------------------------------------------------
    -- 1.7 Colonne de sortie réservée au scoring Python (PD Retail)
    -- ------------------------------------------------------------------------
    CAST(NULL AS DOUBLE) AS predicted_pd_retail

FROM IFRS_9_credit_risk.loan_v1 l

LEFT JOIN IFRS_9_credit_risk.dim_loan_status dls
       ON l.loan_status_id = dls.loan_status_id

WHERE YEAR(l.issue_d_clean) = 2018;


-- ============================================================================
-- 2. DATASET DU MODÈLE PROSPECTIF (MODEL_RETAIL_MACRO – FORWARD-LOOKING)
-- ============================================================================
CREATE OR REPLACE TABLE IFRS_9_credit_risk.model_retail_macro AS

SELECT
    -- ------------------------------------------------------------------------
    -- 2.1 Identifiant et variable cible (Target)
    -- ------------------------------------------------------------------------
    l.id AS loan_id,
    dls.default_flag,

    -- ------------------------------------------------------------------------
    -- 2.2 Profil socio-démographique et financier de l'emprunteur
    -- ------------------------------------------------------------------------
    l.annual_inc,
    l.home_ownership,
    l.emp_length,
    l.verification_status,
    l.addr_state,

    -- ------------------------------------------------------------------------
    -- 2.3 Caractéristiques du contrat de prêt et notation interne
    -- ------------------------------------------------------------------------
    l.loan_amnt,
    l.term,
    l.int_rate,
    l.installment,
    l.purpose,
    l.grade,
    l.sub_grade,

    -- ------------------------------------------------------------------------
    -- 2.4 Comportement de crédit et taux d'utilisation
    -- ------------------------------------------------------------------------
    l.dti,
    l.revol_util,
    l.bc_util,
    l.delinq_2yrs,
    l.inq_last_6mths,
    l.acc_now_delinq,

    -- ------------------------------------------------------------------------
    -- 2.5 Profondeur et incidents de l'historique de crédit
    -- ------------------------------------------------------------------------
    l.open_acc,
    l.total_acc,
    l.pub_rec,
    l.pub_rec_bankruptcies,
    l.tax_liens,

    -- ------------------------------------------------------------------------
    -- 2.6 Encours globaux, structure des comptes et qualité du portefeuille
    -- ------------------------------------------------------------------------
    l.tot_cur_bal,
    l.avg_cur_bal,
    l.mort_acc,
    l.num_actv_bc_tl,
    l.num_actv_rev_tl,
    l.num_bc_tl,
    l.num_rev_accts,
    l.pct_tl_nvr_dlq,
    l.percent_bc_gt_75,

    -- ------------------------------------------------------------------------
    -- 2.7 Variables macroéconomiques FRED (alignement mensuel sur l'octroi)
    -- ------------------------------------------------------------------------
    dm.unemployment_rate_pct,
    dm.cpi_index,
    dm.interest_rate_pct,
    dm.gdp,
    dm.gdp_smooth_2m,

    -- ------------------------------------------------------------------------
    -- 2.8 Colonne de sortie réservée au scoring Python (PD Retail + Macro)
    -- ------------------------------------------------------------------------
    CAST(NULL AS DOUBLE) AS predicted_pd_macro

FROM IFRS_9_credit_risk.loan_v1 l

LEFT JOIN IFRS_9_credit_risk.dim_loan_status dls
       ON l.loan_status_id = dls.loan_status_id

LEFT JOIN IFRS_9_credit_risk.dim_macro dm
       ON DATE_FORMAT(l.issue_d_clean,'yyyy-MM')
       = DATE_FORMAT(dm.macro_date,'yyyy-MM')

WHERE YEAR(l.issue_d_clean) = 2018;
