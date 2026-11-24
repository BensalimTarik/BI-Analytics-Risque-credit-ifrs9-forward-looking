# Databricks notebook source
import pandas as pd
from pandas_datareader import data as pdr

start = "2018-04-01"
end   = "2018-09-30"

# =========================
# MACRO DATA (FRED)
# =========================

unemp = pdr.DataReader("UNRATE", "fred", start, end)
cpi   = pdr.DataReader("CPIAUCSL", "fred", start, end)
rate  = pdr.DataReader("FEDFUNDS", "fred", start, end)
gdp   = pdr.DataReader("GDP", "fred", start, end)

# =========================
# BUILD TABLE
# =========================

df_macro = pd.concat([unemp, cpi, rate, gdp], axis=1)
df_macro.columns = [
    "unemployment_rate_pct",
    "cpi_index",
    "interest_rate_pct",
    "gdp"
]

df_macro = df_macro.reset_index()
df_macro.rename(columns={"DATE": "date"}, inplace=True)

# =========================
# FEATURE ENGINEERING IFRS9
# =========================

df_macro["inflation_yoy_pct"] = df_macro["cpi_index"].pct_change(12) * 100
df_macro["gdp_growth_pct"] = df_macro["gdp"].pct_change() * 100

display(df_macro)

spark_df = spark.createDataFrame(df_macro)

spark_df.write.mode("overwrite").saveAsTable(
    "IFRS_9_credit_risk.stg_macro"
)