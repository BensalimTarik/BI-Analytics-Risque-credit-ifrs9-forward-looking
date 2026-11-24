-- Create table Loan

CREATE OR REPLACE TABLE IFRS_9_credit_risk.Loan (
-- =========================
-- IDENTIFIANTS
-- =========================
id STRING,
member_id STRING,
-- =========================
-- MONTANTS PRÊT
-- =========================
loan_amnt STRING,
funded_amnt STRING,
funded_amnt_inv STRING,
-- =========================
-- INFORMATIONS PRÊT
-- =========================
term STRING,
int_rate STRING,
installment STRING,
grade STRING,
sub_grade STRING,
-- =========================
-- INFORMATIONS EMPLOI / CLIENT
-- =========================
emp_title STRING,
emp_length STRING,
home_ownership STRING,
annual_inc STRING,
verification_status STRING,
-- =========================
-- DATES & STATUT
-- =========================
issue_d STRING,
loan_status STRING,
pymnt_plan STRING,
-- =========================
-- DESCRIPTIF
-- =========================
url STRING,
`desc` STRING,
purpose STRING,
title STRING,
-- =========================
-- LOCALISATION
-- =========================
zip_code STRING,
addr_state STRING,
-- =========================
-- RISQUE CLIENT
-- =========================
dti STRING,
delinq_2yrs STRING,
earliest_cr_line STRING,
inq_last_6mths STRING,
mths_since_last_delinq STRING,
mths_since_last_record STRING,
open_acc STRING,
pub_rec STRING,
revol_bal STRING,
revol_util STRING,
total_acc STRING,
-- =========================
-- EXPOSITION / PAIEMENTS
-- =========================
initial_list_status STRING,
out_prncp STRING,
out_prncp_inv STRING,
total_pymnt STRING,
total_pymnt_inv STRING,
total_rec_prncp STRING,
total_rec_int STRING,
total_rec_late_fee STRING,
recoveries STRING,
collection_recovery_fee STRING,
-- =========================
-- DATES PAIEMENT
-- =========================
last_pymnt_d STRING,
last_pymnt_amnt STRING,
next_pymnt_d STRING,
last_credit_pull_d STRING,
-- =========================
-- REGLEMENTAIRE
-- =========================
collections_12_mths_ex_med STRING,
mths_since_last_major_derog STRING,
policy_code STRING,
application_type STRING,
annual_inc_joint STRING,
dti_joint STRING,
verification_status_joint STRING,
acc_now_delinq STRING,
tot_coll_amt STRING,
tot_cur_bal STRING,
-- =========================
-- OPEN CREDIT
-- =========================
open_acc_6m STRING,
open_act_il STRING,
open_il_12m STRING,
open_il_24m STRING,
mths_since_rcnt_il STRING,
total_bal_il STRING,
il_util STRING,
open_rv_12m STRING,
open_rv_24m STRING,
max_bal_bc STRING,
all_util STRING,
total_rev_hi_lim STRING,
inq_fi STRING,
total_cu_tl STRING,
inq_last_12m STRING,
acc_open_past_24mths STRING,
avg_cur_bal STRING,
bc_open_to_buy STRING,
bc_util STRING,
chargeoff_within_12_mths STRING,
delinq_amnt STRING,
mo_sin_old_il_acct STRING,
mo_sin_old_rev_tl_op STRING,
mo_sin_rcnt_rev_tl_op STRING,
mo_sin_rcnt_tl STRING,
mort_acc STRING,
mths_since_recent_bc STRING,
mths_since_recent_bc_dlq STRING,
mths_since_recent_inq STRING,
mths_since_recent_revol_delinq STRING,
-- =========================
-- CREDIT METRICS
-- =========================
num_accts_ever_120_pd STRING,
num_actv_bc_tl STRING,
num_actv_rev_tl STRING,
num_bc_sats STRING,
num_bc_tl STRING,
num_il_tl STRING,
num_op_rev_tl STRING,
num_rev_accts STRING,
num_rev_tl_bal_gt_0 STRING,
num_sats STRING,
num_tl_120dpd_2m STRING,
num_tl_30dpd STRING,
num_tl_90g_dpd_24m STRING,
num_tl_op_past_12m STRING,
pct_tl_nvr_dlq STRING,
percent_bc_gt_75 STRING,
pub_rec_bankruptcies STRING,
tax_liens STRING,
tot_hi_cred_lim STRING,
total_bal_ex_mort STRING,
total_bc_limit STRING,
total_il_high_credit_limit STRING,
-- =========================
-- JOINT APPLICATION
-- =========================
revol_bal_joint STRING,
sec_app_earliest_cr_line STRING,
sec_app_inq_last_6mths STRING,
sec_app_mort_acc STRING,
sec_app_open_acc STRING,
sec_app_revol_util STRING,
sec_app_open_act_il STRING,
sec_app_num_rev_accts STRING,
sec_app_chargeoff_within_12_mths STRING,
sec_app_collections_12_mths_ex_med STRING,
sec_app_mths_since_last_major_derog STRING,
-- =========================
-- HARDSHIP
-- =========================
hardship_flag STRING,
hardship_type STRING,
hardship_reason STRING,
hardship_status STRING,
deferral_term STRING,
hardship_amount STRING,
hardship_start_date STRING,
hardship_end_date STRING,
payment_plan_start_date STRING,
hardship_length STRING,
hardship_dpd STRING,
hardship_loan_status STRING,
orig_projected_additional_accrued_interest STRING,
hardship_payoff_balance_amount STRING,
hardship_last_payment_amount STRING,
-- =========================
-- SETTLEMENT
-- =========================
disbursement_method STRING,
debt_settlement_flag STRING,
debt_settlement_flag_date STRING,
settlement_status STRING,
settlement_date STRING,
settlement_amount STRING,
settlement_percentage STRING,
settlement_term STRING
)
USING DELTA;


-- Investigate table IFRS_9_credit_risk.Loan
select * from IFRS_9_credit_risk.Loan;


-- Get the first data from csv file
SELECT * 
FROM read_files(
  '/Volumes/workspace/default/loan_volume/Loan_reduced.csv',
  format => 'csv',
  delimiter => ';'
)
LIMIT 5;

-- Copy csv file to the table loan

COPY INTO IFRS_9_credit_risk.Loan
FROM '/Volumes/workspace/default/loan_volume/Loan_reduced.csv'
FILEFORMAT = CSV
FORMAT_OPTIONS (
  'header' = 'true',
  'delimiter' = ';',
  'multiLine' = 'true',
  'quote' = '"',
  'escape' = '"',
  'nullValue' = 'NULL'
);

-- Put the real variables types 

CREATE OR REPLACE TABLE IFRS_9_credit_risk.loan_v0 AS
SELECT
-- =========================
-- IDENTIFIANTS
-- =========================
CAST(id AS BIGINT) AS id,
CAST(member_id AS BIGINT) AS member_id,
-- =========================
-- MONTANTS
-- =========================
CAST(REPLACE(loan_amnt, ',', '.') AS DOUBLE) AS loan_amnt,
CAST(REPLACE(funded_amnt, ',', '.') AS DOUBLE) AS funded_amnt,
CAST(REPLACE(funded_amnt_inv, ',', '.') AS DOUBLE) AS funded_amnt_inv,
-- =========================
-- INFORMATIONS PRET
-- =========================
TRIM(term) AS term,
CAST(REPLACE(int_rate, ',', '.') AS DOUBLE) AS int_rate,
CAST(REPLACE(installment, ',', '.') AS DOUBLE) AS installment,
grade,
sub_grade,
emp_title,
emp_length,
home_ownership,
CAST(REPLACE(annual_inc, ',', '.') AS DOUBLE) AS annual_inc,
verification_status,
issue_d,
loan_status,
pymnt_plan,
url,
`desc`,
purpose,
title,
zip_code,
addr_state,
CAST(REPLACE(dti, ',', '.') AS DOUBLE) AS dti,
CAST(delinq_2yrs AS INT) AS delinq_2yrs,
earliest_cr_line,
CAST(inq_last_6mths AS INT) AS inq_last_6mths,
CAST(mths_since_last_delinq AS INT) AS mths_since_last_delinq,
CAST(mths_since_last_record AS INT) AS mths_since_last_record,
CAST(open_acc AS INT) AS open_acc,
CAST(pub_rec AS INT) AS pub_rec,
CAST(revol_bal AS DOUBLE) AS revol_bal,
CAST(REPLACE(revol_util, ',', '.') AS DOUBLE) AS revol_util,
CAST(total_acc AS INT) AS total_acc,
initial_list_status,
CAST(REPLACE(out_prncp, ',', '.') AS DOUBLE) AS out_prncp,
CAST(REPLACE(out_prncp_inv, ',', '.') AS DOUBLE) AS out_prncp_inv,
CAST(REPLACE(total_pymnt, ',', '.') AS DOUBLE) AS total_pymnt,
CAST(REPLACE(total_pymnt_inv, ',', '.') AS DOUBLE) AS total_pymnt_inv,
CAST(REPLACE(total_rec_prncp, ',', '.') AS DOUBLE) AS total_rec_prncp,
CAST(REPLACE(total_rec_int, ',', '.') AS DOUBLE) AS total_rec_int,
CAST(REPLACE(total_rec_late_fee, ',', '.') AS DOUBLE) AS total_rec_late_fee,
CAST(REPLACE(recoveries, ',', '.') AS DOUBLE) AS recoveries,
CAST(REPLACE(collection_recovery_fee, ',', '.') AS DOUBLE) AS collection_recovery_fee,
last_pymnt_d,
CAST(REPLACE(last_pymnt_amnt, ',', '.') AS DOUBLE) AS last_pymnt_amnt,
next_pymnt_d,
last_credit_pull_d,
CAST(collections_12_mths_ex_med AS INT) AS collections_12_mths_ex_med,
CAST(mths_since_last_major_derog AS INT) AS mths_since_last_major_derog,
CAST(policy_code AS INT) AS policy_code,
application_type,
CAST(REPLACE(annual_inc_joint, ',', '.') AS DOUBLE) AS annual_inc_joint,
CAST(REPLACE(dti_joint, ',', '.') AS DOUBLE) AS dti_joint,
verification_status_joint,
CAST(acc_now_delinq AS INT) AS acc_now_delinq,
CAST(tot_coll_amt AS BIGINT) AS tot_coll_amt,
CAST(tot_cur_bal AS BIGINT) AS tot_cur_bal,
CAST(open_acc_6m AS INT) AS open_acc_6m,
CAST(open_act_il AS INT) AS open_act_il,
CAST(open_il_12m AS INT) AS open_il_12m,
CAST(open_il_24m AS INT) AS open_il_24m,
CAST(mths_since_rcnt_il AS INT) AS mths_since_rcnt_il,
CAST(total_bal_il AS BIGINT) AS total_bal_il,
CAST(il_util AS INT) AS il_util,
CAST(open_rv_12m AS INT) AS open_rv_12m,
CAST(open_rv_24m AS INT) AS open_rv_24m,
CAST(max_bal_bc AS BIGINT) AS max_bal_bc,
CAST(all_util AS INT) AS all_util,
CAST(total_rev_hi_lim AS BIGINT) AS total_rev_hi_lim,
CAST(inq_fi AS INT) AS inq_fi,
CAST(total_cu_tl AS INT) AS total_cu_tl,
CAST(inq_last_12m AS INT) AS inq_last_12m,
CAST(acc_open_past_24mths AS INT) AS acc_open_past_24mths,
CAST(avg_cur_bal AS BIGINT) AS avg_cur_bal,
CAST(bc_open_to_buy AS BIGINT) AS bc_open_to_buy,
CAST(REPLACE(bc_util, ',', '.') AS DOUBLE) AS bc_util,
CAST(chargeoff_within_12_mths AS INT) AS chargeoff_within_12_mths,
CAST(delinq_amnt AS BIGINT) AS delinq_amnt,
CAST(mo_sin_old_il_acct AS INT) AS mo_sin_old_il_acct,
CAST(mo_sin_old_rev_tl_op AS INT) AS mo_sin_old_rev_tl_op,
CAST(mo_sin_rcnt_rev_tl_op AS INT) AS mo_sin_rcnt_rev_tl_op,
CAST(mo_sin_rcnt_tl AS INT) AS mo_sin_rcnt_tl,
CAST(mort_acc AS INT) AS mort_acc,
CAST(mths_since_recent_bc AS INT) AS mths_since_recent_bc,
CAST(mths_since_recent_bc_dlq AS INT) AS mths_since_recent_bc_dlq,
CAST(mths_since_recent_inq AS INT) AS mths_since_recent_inq,
CAST(mths_since_recent_revol_delinq AS INT) AS mths_since_recent_revol_delinq,
CAST(num_accts_ever_120_pd AS INT) AS num_accts_ever_120_pd,
CAST(num_actv_bc_tl AS INT) AS num_actv_bc_tl,
CAST(num_actv_rev_tl AS INT) AS num_actv_rev_tl,
CAST(num_bc_sats AS INT) AS num_bc_sats,
CAST(num_bc_tl AS INT) AS num_bc_tl,
CAST(num_il_tl AS INT) AS num_il_tl,
CAST(num_op_rev_tl AS INT) AS num_op_rev_tl,
CAST(num_rev_accts AS INT) AS num_rev_accts,
CAST(num_rev_tl_bal_gt_0 AS INT) AS num_rev_tl_bal_gt_0,
CAST(num_sats AS INT) AS num_sats,
CAST(num_tl_120dpd_2m AS INT) AS num_tl_120dpd_2m,
CAST(num_tl_30dpd AS INT) AS num_tl_30dpd,
CAST(num_tl_90g_dpd_24m AS INT) AS num_tl_90g_dpd_24m,
CAST(num_tl_op_past_12m AS INT) AS num_tl_op_past_12m,
CAST(REPLACE(pct_tl_nvr_dlq, ',', '.') AS DOUBLE) AS pct_tl_nvr_dlq,
CAST(REPLACE(percent_bc_gt_75, ',', '.') AS DOUBLE) AS percent_bc_gt_75,
CAST(pub_rec_bankruptcies AS INT) AS pub_rec_bankruptcies,
CAST(tax_liens AS INT) AS tax_liens,
CAST(tot_hi_cred_lim AS BIGINT) AS tot_hi_cred_lim,
CAST(total_bal_ex_mort AS BIGINT) AS total_bal_ex_mort,
CAST(total_bc_limit AS BIGINT) AS total_bc_limit,
CAST(total_il_high_credit_limit AS BIGINT) AS total_il_high_credit_limit,
CAST(revol_bal_joint AS BIGINT) AS revol_bal_joint,
sec_app_earliest_cr_line,
CAST(sec_app_inq_last_6mths AS INT) AS sec_app_inq_last_6mths,
CAST(sec_app_mort_acc AS INT) AS sec_app_mort_acc,
CAST(sec_app_open_acc AS INT) AS sec_app_open_acc,
CAST(REPLACE(sec_app_revol_util, ',', '.') AS DOUBLE) AS sec_app_revol_util,
CAST(sec_app_open_act_il AS INT) AS sec_app_open_act_il,
CAST(sec_app_num_rev_accts AS INT) AS sec_app_num_rev_accts,
CAST(sec_app_chargeoff_within_12_mths AS INT) AS sec_app_chargeoff_within_12_mths,
CAST(sec_app_collections_12_mths_ex_med AS INT) AS sec_app_collections_12_mths_ex_med,
CAST(sec_app_mths_since_last_major_derog AS INT) AS sec_app_mths_since_last_major_derog,
hardship_flag,
hardship_type,
hardship_reason,
hardship_status,
CAST(deferral_term AS INT) AS deferral_term,
CAST(REPLACE(hardship_amount, ',', '.') AS DOUBLE) AS hardship_amount,
hardship_start_date,
hardship_end_date,
payment_plan_start_date,
CAST(hardship_length AS INT) AS hardship_length,
CAST(hardship_dpd AS INT) AS hardship_dpd,
hardship_loan_status,
CAST(REPLACE(orig_projected_additional_accrued_interest, ',', '.') AS DOUBLE) AS orig_projected_additional_accrued_interest,
CAST(REPLACE(hardship_payoff_balance_amount, ',', '.') AS DOUBLE) AS hardship_payoff_balance_amount,
CAST(REPLACE(hardship_last_payment_amount, ',', '.') AS DOUBLE) AS hardship_last_payment_amount,
disbursement_method,
debt_settlement_flag,
debt_settlement_flag_date,
settlement_status,
settlement_date,
CAST(REPLACE(settlement_amount, ',', '.') AS DOUBLE) AS settlement_amount,
CAST(REPLACE(settlement_percentage, ',', '.') AS DOUBLE) AS settlement_percentage,
CAST(settlement_term AS INT) AS settlement_term
FROM IFRS_9_credit_risk.Loan;

-- Create a copy storage loan_vs 'storage version'
CREATE TABLE IFRS_9_credit_risk.loan_vs AS SELECT * FROM IFRS_9_credit_risk.loan_v0;




