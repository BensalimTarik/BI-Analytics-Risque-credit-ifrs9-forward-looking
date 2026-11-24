# =====================================
# LIBRARIES
# =====================================

import pandas as pd
import numpy as np

from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline

from sklearn.impute import SimpleImputer
from sklearn.preprocessing import OneHotEncoder
from sklearn.preprocessing import StandardScaler

from sklearn.linear_model import LogisticRegression

from sklearn.metrics import (
    roc_auc_score,
    roc_curve,
    brier_score_loss
)

# =====================================
# Fonction PSI
# =====================================


def calculate_psi(expected, actual, buckets=10):

    expected = np.array(expected)
    actual = np.array(actual)

    breakpoints = np.percentile(
        expected,
        np.arange(0, buckets + 1) / buckets * 100
    )

    expected_counts = np.histogram(expected, bins=breakpoints)[0]
    actual_counts = np.histogram(actual, bins=breakpoints)[0]

    expected_pct = expected_counts / len(expected)
    actual_pct = actual_counts / len(actual)

    expected_pct = np.where(expected_pct == 0, 0.0001, expected_pct)
    actual_pct = np.where(actual_pct == 0, 0.0001, actual_pct)

    psi = np.sum(
        (actual_pct - expected_pct)
        *
        np.log(actual_pct / expected_pct)
    )

    return psi

# =====================================
# LOAD DATA - Retail table
# =====================================

df_retail = spark.table(
    "IFRS_9_credit_risk.model_retail"
).toPandas()

print(df_retail.shape)

# =====================================
# LOAD DATA - Retail & Macro table
# =====================================

df_retail_macro = spark.table(
    "IFRS_9_credit_risk.model_retail_macro"
).toPandas()

print(df_retail_macro.shape)


# =====================================
# TARGET
# =====================================

y1 = df_retail["default_flag"]
y2 = df_retail_macro["default_flag"]

# =====================================
# FEATURES
# =====================================

X1 = df_retail.drop(
    columns=[
        "loan_id",
        "default_flag",
        "predicted_pd_retail"
    ],
    errors="ignore"
)

X2 = df_retail_macro.drop(
    columns=[
        "loan_id",
        "default_flag",
        "predicted_pd_macro"
    ],
    errors="ignore"
)

# =====================================
# NUMERIC / CATEGORICAL - Retail Table
# =====================================

numeric_features_1 = X1.select_dtypes(
    include=["int64","float64"]
).columns

categorical_features_1 = X1.select_dtypes(
    include=["object"]
).columns

print("Numeric - Retail:", len(numeric_features_1))
print("Categorical - Retail:", len(categorical_features_1))


# =====================================
# NUMERIC / CATEGORICAL - Retail & Macro Table
# =====================================

numeric_features_2 = X2.select_dtypes(
    include=["int64", "float64"]
).columns.tolist()

categorical_features_2 = X2.select_dtypes(
    include=["object"]
).columns.tolist()

print("Numeric - Retail & Macro:", len(numeric_features_2))
print("Categorical - Retail & Macro:", len(categorical_features_2))

# =====================================
# PREPROCESSING - Retail Table
# =====================================

numeric_transformer_1 = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler())
    ]
)

categorical_transformer_1 = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore"))
    ]
)

preprocessor_1 = ColumnTransformer(
    transformers=[
        ("num", numeric_transformer_1, numeric_features_1),
        ("cat", categorical_transformer_1, categorical_features_1)
    ]
)

# =====================================
# PREPROCESSING - Retail & Macro Table
# =====================================

numeric_transformer_2 = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler())
    ]
)

categorical_transformer_2 = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore"))
    ]
)

preprocessor_2 = ColumnTransformer(
    transformers=[
        ("num", numeric_transformer_2, numeric_features_2),
        ("cat", categorical_transformer_2, categorical_features_2)
    ]
)

# =====================================
# TRAIN TEST SPLIT - Retail Table
# =====================================

X_train_1, X_test_1, y_train_1, y_test_1 = train_test_split(
    X1,
    y1,
    test_size=0.30,
    random_state=42,
    stratify=y1
)

# =====================================================
# TRAIN TEST SPLIT - Retail & Macro Table
# =====================================================

X_train_2, X_test_2, y_train_2, y_test_2 = train_test_split(
    X2,
    y2,
    test_size=0.30,
    random_state=42,
    stratify=y2
)

# =====================================
# MODEL - Logistic Regression - Retail Table 
# =====================================

model_LR_Retail = Pipeline(
    steps=[
        ("preprocessor", preprocessor_1),
        ("classifier",
            LogisticRegression(
                max_iter=2000
            )
        )
    ]
)

model_LR_Retail.fit(X_train_1, y_train_1)

# ==================================================
# MODEL - Logistic Regression - Retail & Macro Table 
# ==================================================

model_LR_Retail_Macro = Pipeline(
    steps=[
        ("preprocessor", preprocessor_2),
        ("classifier",
            LogisticRegression(
                max_iter=2000
            )
        )
    ]
)

model_LR_Retail_Macro.fit(X_train_2, y_train_2)

# =====================================
# PD PREDICTIONS
# =====================================

pd_pred_LR_Retail = model_LR_Retail.predict_proba(X_test_1)[:,1]
pd_pred_LR_Retail_Macro = model_LR_Retail_Macro.predict_proba(X_test_2)[:,1]


# =====================================
# AUC
# =====================================

auc_1 = roc_auc_score(
    y_test_1,
    pd_pred_LR_Retail
)

auc_2 = roc_auc_score(
    y_test_2,
    pd_pred_LR_Retail_Macro
)

print("AUC LR Retail =", round(auc_1,4))
print("AUC LR Retail & Macro =", round(auc_2,4))

# =====================================
# GINI
# =====================================

gini_1 = 2*auc_1 - 1
gini_2 = 2*auc_2 - 1

print("GINI LR Retail =", round(gini_1,4))
print("GINI LR Retail & Macro =", round(gini_2,4))

# =====================================
# BRIER
# =====================================

brier_1 = brier_score_loss(
    y_test_1,
    pd_pred_LR_Retail
)

brier_2 = brier_score_loss(
    y_test_2,
    pd_pred_LR_Retail_Macro
)


print("BRIER LR Retail =", round(brier_1,4))
print("BRIER LR Retail & Macro =", round(brier_2,4))

# =====================================
# KS Statistic
# =====================================

fpr_1, tpr_1, thresholds_1 = roc_curve(
    y_test_1,
    pd_pred_LR_Retail
)

ks_1 = np.max(tpr_1 - fpr_1)

fpr_2, tpr_2, thresholds_2 = roc_curve(
    y_test_2,
    pd_pred_LR_Retail_Macro
)

ks_2 = np.max(tpr_2 - fpr_2)

print("KS LR Retail =", round(ks_1,4))
print("KS LR Retail & Macro =", round(ks_2,4))

# =====================================
# ROC TABLE - CURVE
# =====================================

roc_retail = pd.DataFrame({

    "Model": "LR Retail",

    "False_Positive_Rate": fpr_1,

    "True_Positive_Rate": tpr_1,

    "Threshold": thresholds_1

})

roc_macro = pd.DataFrame({

    "Model": "LR Retail + Macro",

    "False_Positive_Rate": fpr_2,

    "True_Positive_Rate": tpr_2,

    "Threshold": thresholds_2

})

roc_table = pd.concat(
    [
        roc_retail,
        roc_macro
    ],
    ignore_index=True
)

spark.createDataFrame(roc_table) \
    .write \
    .mode("overwrite") \
    .saveAsTable(
        "IFRS_9_credit_risk.model_lr_roc"
    )

print("ROC table créée avec succès.")

# =====================================
# PSI
# =====================================

train_pd = model_LR_Retail.predict_proba(X_train_1)[:,1]
test_pd = model_LR_Retail.predict_proba(X_test_1)[:,1]

psi_1 = calculate_psi(
    train_pd,
    test_pd
)

train_pd_macro = model_LR_Retail_Macro.predict_proba(X_train_2)[:,1]
test_pd_macro = model_LR_Retail_Macro.predict_proba(X_test_2)[:,1]

psi_2 = calculate_psi(
    train_pd_macro,
    test_pd_macro
)

print("PSI =", round(psi_1,4))
print("PSI Macro =", round(psi_2,4))

# =====================================
# CSI
# =====================================

csi_income_1 = calculate_psi(
    X_train_1["annual_inc"],
    X_test_1["annual_inc"]
)

csi_income_2 = calculate_psi(
    X_train_2["annual_inc"],
    X_test_2["annual_inc"]
)


# =====================================
# DTI
# =====================================

csi_dti_1 = calculate_psi(
    X_train_1["dti"],
    X_test_1["dti"]
)

csi_dti_2 = calculate_psi(
    X_train_2["dti"],
    X_test_2["dti"]
)


# =====================================
# Revol Util
# =====================================

csi_revol_1 = calculate_psi(
    X_train_1["revol_util"],
    X_test_1["revol_util"]
)

csi_revol_2 = calculate_psi(
    X_train_1["revol_util"],
    X_test_1["revol_util"]
)

# ========================================
# Sauvegarder les PD dans une seule table 
# ========================================

df_scoring = pd.DataFrame({

    "loan_id": df_retail["loan_id"],

    "default_flag": df_retail["default_flag"],

    "predicted_pd_LR_retail":
        model_LR_Retail.predict_proba(X1)[:,1],

    "predicted_pd_LR_macro":
        model_LR_Retail_Macro.predict_proba(X2)[:,1]

})

spark.createDataFrame(df_scoring) \
    .write \
    .mode("overwrite") \
    .saveAsTable(
        "IFRS_9_credit_risk.model_lr_scoring"
    )

# ======================================================================
# Sauvegarder les statistiques de performance model dans une seule table 
# ======================================================================

performance = pd.DataFrame({

    "metric":[
        "AUC",
        "GINI",
        "KS",
        "BRIER",
        "PSI",
        "CSI Annual Income",
        "CSI DTI",
        "CSI Revol Util"
    ],

    "LR_Retail":[
        auc_1,
        gini_1,
        ks_1,
        brier_1,
        psi_1,
        csi_income_1,
        csi_dti_1,
        csi_revol_1
    ],

    "LR_Retail_Macro":[
        auc_2,
        gini_2,
        ks_2,
        brier_2,
        psi_2,
        csi_income_2,
        csi_dti_2,
        csi_revol_2
    ]
})

spark.createDataFrame(performance) \
    .write \
    .mode("overwrite") \
    .saveAsTable(
        "IFRS_9_credit_risk.model_lr_performance"
    )

# ===========================================================
# FEATURE IMPORTANCE - LR Retail
# ===========================================================

feature_names_1 = model_LR_Retail.named_steps[
    "preprocessor"
].get_feature_names_out()

coefficients_1 = model_LR_Retail.named_steps[
    "classifier"
].coef_[0]

importance_1 = pd.DataFrame({

    "Model": "LR Retail",
    "Variable": feature_names_1,
    "Coefficient": coefficients_1,
    "Importance": np.abs(coefficients_1)
})

# ===========================================================
# FEATURE IMPORTANCE - LR Retail + Macro
# ===========================================================

feature_names_2 = model_LR_Retail_Macro.named_steps[
    "preprocessor"
].get_feature_names_out()

coefficients_2 = model_LR_Retail_Macro.named_steps[
    "classifier"
].coef_[0]

importance_2 = pd.DataFrame({

    "Model": "LR Retail + Macro",
    "Variable": feature_names_2,
    "Coefficient": coefficients_2,
    "Importance": np.abs(coefficients_2)

})

# ===========================================================
# COMBINE BOTH MODELS
# ===========================================================

feature_importance = pd.concat(
    [importance_1, importance_2],
    ignore_index=True
)

feature_importance = feature_importance.sort_values(
    ["Model", "Importance"],
    ascending=[True, False]
)

# ===========================================================
# SAVE TABLE
# ===========================================================

spark.createDataFrame(feature_importance) \
    .write \
    .mode("overwrite") \
    .saveAsTable(
        "IFRS_9_credit_risk.model_lr_feature_importance"
    )

print("Table model_lr_feature_importance créée avec succès.")

# ===========================================================
# CALIBRATION - LR RETAIL
# ===========================================================

calibration_retail = pd.DataFrame({

    "loan_id": df_retail["loan_id"],
    "default_flag": df_retail["default_flag"],
    "predicted_pd":
        model_LR_Retail.predict_proba(X1)[:,1],
    "Model":"LR Retail"

})

calibration_retail["Decile"] = pd.qcut(

    calibration_retail["predicted_pd"],
    10,
    labels=False,
    duplicates="drop"
)

calibration_retail = calibration_retail.groupby(
    ["Model","Decile"]
).agg(
    Avg_PD=("predicted_pd","mean"),
    Observed_Default=("default_flag","mean"),
    Loans=("loan_id","count")
).reset_index()

# ===========================================================
# CALIBRATION - LR RETAIL + MACRO
# ===========================================================

calibration_macro = pd.DataFrame({

    "loan_id": df_retail_macro["loan_id"],
    "default_flag": df_retail_macro["default_flag"],
    "predicted_pd":
        model_LR_Retail_Macro.predict_proba(X2)[:,1],
    "Model":"LR Retail + Macro"
})

calibration_macro["Decile"] = pd.qcut(

    calibration_macro["predicted_pd"],
    10,
    labels=False,
    duplicates="drop"
)

calibration_macro = calibration_macro.groupby(

    ["Model","Decile"]
).agg(

    Avg_PD=("predicted_pd","mean"),
    Observed_Default=("default_flag","mean"),
    Loans=("loan_id","count")
).reset_index()

# ===========================================================
# COMBINE
# ===========================================================

calibration = pd.concat(

    [calibration_retail, calibration_macro],
    ignore_index=True
)

spark.createDataFrame(calibration) \
.write.mode("overwrite") \
.saveAsTable(
    "IFRS_9_credit_risk.model_lr_calibration"
)

print("Calibration table created.")

# ===========================================================
# SHAP
# ===========================================================

# %pip install shap
import shap

# ===========================================================
# SHAP - Logistic Regression Retail
# ===========================================================
# ===========================================================
# SHAP VALUES - LR RETAIL
# ===========================================================

# Données préprocessées
X_train_processed_1 = model_LR_Retail.named_steps[
    "preprocessor"
].transform(X_train_1)

X_processed_1 = model_LR_Retail.named_steps[
    "preprocessor"
].transform(X1)

# Explainer
explainer_1 = shap.LinearExplainer(
    model_LR_Retail.named_steps["classifier"],
    X_train_processed_1
)

# SHAP values
shap_values_1 = explainer_1.shap_values(X_processed_1)

# Variables
feature_names_1 = model_LR_Retail.named_steps[
    "preprocessor"
].get_feature_names_out()

# DataFrame
shap_df_1 = pd.DataFrame(
    shap_values_1,
    columns=feature_names_1
)

shap_df_1["loan_id"] = df_retail["loan_id"].values
shap_df_1["Model"] = "LR Retail"

# ===========================================================
# SHAP - Logistic Regression Retail + Macro
# ===========================================================
# ===========================================================
# SHAP VALUES - LR RETAIL + MACRO
# ===========================================================

X_train_processed_2 = model_LR_Retail_Macro.named_steps[
    "preprocessor"
].transform(X_train_2)

X_processed_2 = model_LR_Retail_Macro.named_steps[
    "preprocessor"
].transform(X2)

explainer_2 = shap.LinearExplainer(
    model_LR_Retail_Macro.named_steps["classifier"],
    X_train_processed_2
)

shap_values_2 = explainer_2.shap_values(X_processed_2)

feature_names_2 = model_LR_Retail_Macro.named_steps[
    "preprocessor"
].get_feature_names_out()

shap_df_2 = pd.DataFrame(
    shap_values_2,
    columns=feature_names_2
)

shap_df_2["loan_id"] = df_retail_macro["loan_id"].values
shap_df_2["Model"] = "LR Retail + Macro"

# ===========================================================
# LONG FORMAT - Transformation en format long
# ===========================================================

shap_long_1 = shap_df_1.melt(

    id_vars=[
        "loan_id",
        "Model"
    ],
    var_name="Variable",
    value_name="SHAP_Value"

)

shap_long_2 = shap_df_2.melt(

    id_vars=[
        "loan_id",
        "Model"
    ],

    var_name="Variable",
    value_name="SHAP_Value"
)

# Fusion

model_lr_shap = pd.concat(
    [
        shap_long_1,
        shap_long_2
    ],
    ignore_index=True
)

# ===========================================================
# SAVE TABLE
# ===========================================================
spark.createDataFrame(model_lr_shap) \
    .write \
    .mode("overwrite") \
    .saveAsTable(
        "IFRS_9_credit_risk.model_lr_shap"
    )
print("Table model_lr_shap créée avec succès.")

