# Databricks notebook source
# Get table from SQL
df = spark.table("IFRS_9_credit_risk.loan_v0")

# Important columns to keep
columns_to_keep = [
    "id",
    "member_id",
    "loan_amnt",
    "funded_amnt",
    "funded_amnt_inv",
    "term",
    "int_rate",
    "installment",
    "grade",
    "sub_grade",
    "emp_title",
    "emp_length",
    "home_ownership",
    "annual_inc",
    "verification_status",
    "issue_d",
    "loan_status",
    "purpose",
    "title",
    "zip_code",
    "addr_state",
    "dti",
    "delinq_2yrs",
    "earliest_cr_line",
    "inq_last_6mths",
    "open_acc",
    "pub_rec",
    "revol_bal",
    "revol_util",
    "total_acc",
    "out_prncp",
    "out_prncp_inv",
    "total_pymnt",
    "total_pymnt_inv",
    "total_rec_prncp",
    "total_rec_int",
    "total_rec_late_fee",
    "recoveries",
    "collection_recovery_fee",
    "last_pymnt_d",
    "last_pymnt_amnt",
    "next_pymnt_d",
    "last_credit_pull_d",
    "application_type",
    "acc_now_delinq",
    "tot_cur_bal",
    "total_bal_il",
    "total_rev_hi_lim",
    "acc_open_past_24mths",
    "avg_cur_bal",
    "bc_util",
    "mort_acc",
    "num_actv_bc_tl",
    "num_actv_rev_tl",
    "num_bc_tl",
    "num_rev_accts",
    "pct_tl_nvr_dlq",
    "percent_bc_gt_75",
    "pub_rec_bankruptcies",
    "tax_liens",
    "tot_hi_cred_lim",
    "total_bal_ex_mort",
    "total_bc_limit",
    "total_il_high_credit_limit",
    "hardship_flag",
    "debt_settlement_flag"
]

df_clean = df.select(columns_to_keep)

df_clean.write.mode("overwrite").saveAsTable(
    "IFRS_9_credit_risk.loan_v1_py"
)

# Add incremental id

from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Load table
df = spark.table("IFRS_9_credit_risk.loan_v1_py")

# Drop old id column
df = df.drop("id")

# Window spec
window_spec = Window.orderBy(F.monotonically_increasing_id())

# Add new incremental id
df = df.withColumn(
    "id",
    F.row_number().over(window_spec)
)

# Put id first
cols = ["id"] + [c for c in df.columns if c != "id"]
df = df.select(cols)

# Save with schema overwrite
(
    df.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .format("delta")
    .saveAsTable("IFRS_9_credit_risk.loan_v1_py")
)

df = spark.table("IFRS_9_credit_risk.loan_v1_py")
df.show(100)