# Databricks notebook source
# ============================================================================
# PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
# SCRIPT      : 03_macro_data_fred_ifrs9.py
# DESCRIPTION : Extraction automatisée des séries temporelles macroéconomiques 
#               depuis l'API FRED (Federal Reserve Economic Data), calcul des 
#               variables prospectives (inflation YoY, croissance du PIB) et 
#               chargement dans la table de staging Delta Lake (stg_macro).
# ============================================================================


# ============================================================================
# 1. IMPORTATION DES BIBLIOTHÈQUES ET DÉFINITION DE LA PÉRIODE D'ÉTUDE
# ============================================================================
import pandas as pd
from pandas_datareader import data as pdr

start = "2018-04-01"
end   = "2018-09-30"


# ============================================================================
# 2. EXTRACTION DES INDICATEURS MACROÉCONOMIQUES (API FRED)
# ============================================================================
# UNRATE   : Taux de chômage civil américain (%)
# CPIAUCSL : Indice des prix à la consommation (Base 100)
# FEDFUNDS : Taux directeur effectif de la Réserve fédérale (%)
# GDP      : Produit Intérieur Brut américain (Milliards de dollars)
unemp = pdr.DataReader("UNRATE", "fred", start, end)
cpi   = pdr.DataReader("CPIAUCSL", "fred", start, end)
rate  = pdr.DataReader("FEDFUNDS", "fred", start, end)
gdp   = pdr.DataReader("GDP", "fred", start, end)


# ============================================================================
# 3. CONSOLIDATION ET STANDARDISATION DU DATAFRAME MACROÉCONOMIQUE
# ============================================================================
df_macro = pd.concat([unemp, cpi, rate, gdp], axis=1)
df_macro.columns = [
    "unemployment_rate_pct",
    "cpi_index",
    "interest_rate_pct",
    "gdp"
]

df_macro = df_macro.reset_index()
df_macro.rename(columns={"DATE": "date"}, inplace=True)


# ============================================================================
# 4. FEATURE ENGINEERING IFRS 9 (VARIABLES PROSPECTIVES)
# ============================================================================
# Calcul du taux d'inflation annuel (glissement annuel sur 12 mois)
df_macro["inflation_yoy_pct"] = df_macro["cpi_index"].pct_change(12) * 100

# Calcul du taux de croissance périodique du PIB
df_macro["gdp_growth_pct"] = df_macro["gdp"].pct_change() * 100

# Contrôle visuel du jeu de données consolidé
display(df_macro)


# ============================================================================
# 5. CONVERSION SPARK ET SAUVEGARDE DANS DELTA LAKE (STG_MACRO)
# ============================================================================
spark_df = spark.createDataFrame(df_macro)

spark_df.write.mode("overwrite").saveAsTable(
    "IFRS_9_credit_risk.stg_macro"
)
