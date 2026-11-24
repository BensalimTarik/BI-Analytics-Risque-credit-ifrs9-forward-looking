# Databricks notebook source
# ============================================================================
# PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
# SCRIPT      : 02_data_preparation_cleaning.py
# DESCRIPTION : Chargement de la table standardisée (loan_v0), sélection des 
#               variables financières et de risque pertinentes pour la 
#               modélisation IFRS 9, et sauvegarde de la table cible (loan_pv1).
# ============================================================================


# ============================================================================
# 1. CHARGEMENT DE LA TABLE SOURCE STANDARDISÉE (LOAN_V0)
# ============================================================================
df = spark.table("IFRS_9_credit_risk.loan_v0")


# ============================================================================
# 2. SÉLECTION DES VARIABLES MÉTIER ET DE RISQUE RETENUES
# ============================================================================
columns_to_keep = [
    # --- 2.1 Identifiants ---
    "id",
    "member_id",

    # --- 2.2 Montants et conditions du prêt ---
    "loan_amnt",
    "funded_amnt",
    "funded_amnt_inv",
    "term",
    "int_rate",
    "installment",
    "grade",
    "sub_grade",

    # --- 2.3 Profil socio-professionnel de l'emprunteur ---
    "emp_title",
    "emp_length",
    "home_ownership",
    "annual_inc",
    "verification_status",

    # --- 2.4 Dates, statut et objet du prêt ---
    "issue_d",
    "loan_status",
    "purpose",
    "title",

    # --- 2.5 Localisation géographique ---
    "zip_code",
    "addr_state",

    # --- 2.6 Indicateurs d'endettement et historique de crédit ---
    "dti",
    "delinq_2yrs",
    "earliest_cr_line",
    "inq_last_6mths",
    "open_acc",
    "pub_rec",
    "revol_bal",
    "revol_util",
    "total_acc",

    # --- 2.7 Exposition au défaut (EAD), remboursements et recouvrements ---
    "out_prncp",
    "out_prncp_inv",
    "total_pymnt",
    "total_pymnt_inv",
    "total_rec_prncp",
    "total_rec_int",
    "total_rec_late_fee",
    "recoveries",
    "collection_recovery_fee",

    # --- 2.8 Dates de paiement et consultation crédit ---
    "last_pymnt_d",
    "last_pymnt_amnt",
    "next_pymnt_d",
    "last_credit_pull_d",

    # --- 2.9 Encours globaux, structure des comptes et qualité du portefeuille ---
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

    # --- 2.10 Indicateurs de restructuration et difficultés financières ---
    "hardship_flag",
    "debt_settlement_flag"
]


# ============================================================================
# 3. FILTRAGE DES COLONNES ET SAUVEGARDE DANS DELTA LAKE (LOAN_PV1)
# ============================================================================
df_pv1 = df.select(columns_to_keep)

df_pv1.write.mode("overwrite").saveAsTable(
    "IFRS_9_credit_risk.loan_pv1"
)
