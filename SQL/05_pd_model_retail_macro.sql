
----- Table model_retail

CREATE OR REPLACE TABLE IFRS_9_credit_risk.model_retail AS

SELECT

    -- KEY
    l.id AS loan_id,

    -- TARGET
    dls.default_flag,

    -- CLIENT
    l.annual_inc,
    l.home_ownership,
    l.emp_length,
    l.verification_status,

    -- LOAN
    l.loan_amnt,
    l.term,
    l.int_rate,
    l.installment,

    -- PRODUCT
    l.purpose,

    -- RATING
    l.grade,
    l.sub_grade,

    -- CREDIT BEHAVIOR
    l.dti,
    l.revol_util,
    l.bc_util,

    l.delinq_2yrs,
    l.inq_last_6mths,
    l.acc_now_delinq,

    -- CREDIT HISTORY
    l.open_acc,
    l.total_acc,

    l.pub_rec,
    l.pub_rec_bankruptcies,
    l.tax_liens,

    -- BALANCES
    l.tot_cur_bal,
    l.avg_cur_bal,

    -- MORTGAGE
    l.mort_acc,

    -- ACCOUNT STRUCTURE
    l.num_actv_bc_tl,
    l.num_actv_rev_tl,
    l.num_bc_tl,
    l.num_rev_accts,

    -- CREDIT QUALITY
    l.pct_tl_nvr_dlq,
    l.percent_bc_gt_75,

    -- GEOGRAPHY
    l.addr_state,

    -- MODEL OUTPUT
    CAST(NULL AS DOUBLE) AS predicted_pd_retail

FROM IFRS_9_credit_risk.loan_v1 l

LEFT JOIN IFRS_9_credit_risk.dim_loan_status dls
       ON l.loan_status_id = dls.loan_status_id

WHERE YEAR(l.issue_d_clean) = 2018;
------------------------------------------------------------------------------------------------------------------------------------
------ Table model_retail_macro

CREATE OR REPLACE TABLE IFRS_9_credit_risk.model_retail_macro AS

SELECT

    -- KEY
    l.id AS loan_id,

    -- TARGET
    dls.default_flag,

    -- CLIENT
    l.annual_inc,
    l.home_ownership,
    l.emp_length,
    l.verification_status,

    -- LOAN
    l.loan_amnt,
    l.term,
    l.int_rate,
    l.installment,

    -- PRODUCT
    l.purpose,

    -- RATING
    l.grade,
    l.sub_grade,

    -- CREDIT BEHAVIOR
    l.dti,
    l.revol_util,
    l.bc_util,

    l.delinq_2yrs,
    l.inq_last_6mths,
    l.acc_now_delinq,

    -- CREDIT HISTORY
    l.open_acc,
    l.total_acc,

    l.pub_rec,
    l.pub_rec_bankruptcies,
    l.tax_liens,

    -- BALANCES
    l.tot_cur_bal,
    l.avg_cur_bal,

    -- MORTGAGE
    l.mort_acc,

    -- ACCOUNT STRUCTURE
    l.num_actv_bc_tl,
    l.num_actv_rev_tl,
    l.num_bc_tl,
    l.num_rev_accts,

    -- CREDIT QUALITY
    l.pct_tl_nvr_dlq,
    l.percent_bc_gt_75,

    -- GEOGRAPHY
    l.addr_state,

    -- MACRO VARIABLES
    dm.unemployment_rate_pct,
    dm.cpi_index,
    dm.interest_rate_pct,
    dm.gdp,
    dm.gdp_smooth_2m,

    -- MODEL OUTPUT
    CAST(NULL AS DOUBLE) AS predicted_pd_macro

FROM IFRS_9_credit_risk.loan_v1 l

LEFT JOIN IFRS_9_credit_risk.dim_loan_status dls
       ON l.loan_status_id = dls.loan_status_id

LEFT JOIN IFRS_9_credit_risk.dim_macro dm
       ON DATE_FORMAT(l.issue_d_clean,'yyyy-MM')
       = DATE_FORMAT(dm.macro_date,'yyyy-MM')

WHERE YEAR(l.issue_d_clean) = 2018;
