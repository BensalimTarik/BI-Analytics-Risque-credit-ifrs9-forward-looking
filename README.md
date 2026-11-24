# BI-Analytics-Risque-Credit-IFRS9-Forward-Looking
Analytics-BI-Risque-Credit-IFRS9-Forward-Looking
# Pilotage du Risque de Crédit IFRS 9 (Forward-Looking) | Databricks & Power BI

## Présentation du projet

Ce projet présente une solution décisionnelle et quantitative de bout en bout dédiée à la modélisation et au pilotage prospectif (**Forward-Looking**) du **risque de crédit sous la norme IFRS 9**.

Il couvre l'ensemble de la chaîne de valeur de la donnée : extraction depuis **SQL Server**, ingénierie des données et modélisation en étoile sur **Databricks** (PySpark & Delta Lake), enrichissement avec les séries macroéconomiques de la **FRED** (Réserve fédérale américaine), entraînement de modèles de Probabilité de Défaut (**LR Retail vs LR Retail + Macro**), et restitution interactive sous **Power BI**.

Le tableau de bord permet aux directions des risques et aux analystes quantitatifs d'explorer les expositions (**EAD**), les actifs pondérés par les risques (**RWA**), les pertes de crédit attendues (**ECL**), la performance des modèles (AUC, Gini, KS, SHAP) ainsi que la sensibilité aux scénarios de stress macroéconomiques (*Baseline*, *Adverse*, *Severe*) sur l'année **2018**.

## Aperçu du tableau de bord

Le rapport Power BI est organisé en **5 vues analytiques** interactives :

<table>
  <tr>
    <td align="center">
      <img src="Dashboard-Preview/1 - Aperçu niveau direction.jpg" width="100%" alt="Aperçu niveau direction"/>
      <br/><b>1. Aperçu niveau direction</b>
    </td>
    <td align="center">
      <img src="Dashboard-Preview/2 - Analyse du risque de credit.jpg" width="100%" alt="Analyse du risque de crédit"/>
      <br/><b>2. Analyse du risque de crédit</b>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="Dashboard-Preview/3 - Performance des modeles ECL IFRS 9.jpg" width="100%" alt="Performance des modèles ECL IFRS 9"/>
      <br/><b>3. Performance des modèles ECL IFRS 9</b>
    </td>
    <td align="center">
      <img src="Dashboard-Preview/4 - Perspectives et impact macroeconomique.jpg" width="100%" alt="Perspectives & impact macroéconomique"/>
      <br/><b>4. Perspectives & impact macroéconomique</b>
    </td>
  </tr>
  <tr>
    <td align="center" colspan="2">
      <img src="Dashboard-Preview/5 - Tests de resistance du modele.jpg" width="50%" alt="Tests de résistance du modèle"/>
      <br/><b>5. Tests de résistance du modèle (Stress Testing)</b>
    </td>
  </tr>
</table>

## Chiffres clés (Portefeuille & Modèles)

| Indicateur | Valeur |
|---|---:|
| Total RWA (Actifs pondérés par les risques) | 317,04 M\$ |
| Densité des RWA | 69,65 % |
| Ratio CET1 | 17,23 % |
| Exigence en fonds propres | 25,36 M\$ |
| Total EAD (Exposition au défaut) | 455,18 M\$ |
| Total ECL (Pertes de crédit attendues) | 8,12 M\$ |
| Coût du risque | 1,78 % |
| Ratio de couverture | 74,98 % |
| Taux de défaut / Ratio NPL | 3,76 % / 2,38 % |
| Moyenne PD / LGD moyen | 3,92 % / 37,34 % |
| Répartition RWA par Stage (Stage 1 / Stage 2 / Stage 3) | 95,88 % / 2,16 % / 1,96 % |
| Performance du modèle (AUC / Gini / KS / Brier) | 0,772 / 54,34 % / 41,26 % / 0,019 |
| Stabilité du modèle (PSI / CSI) | 0,00063 / 0,000395 |
| Impact Stress Test (ΔPD / ΔECL / Capital consommé) | +50,00 % / +50,00 % / 2,15 M\$ |

## Principaux axes d'analyse

- **Aperçu niveau direction :** suivi prudentiel global des RWA, de la solvabilité (CET1), des exigences en fonds propres, du coût du risque et de la ventilation par Stage IFRS 9.
- **Analyse du risque de crédit :** étude approfondie des paramètres PD, LGD et EAD par grade de notation (`A` à `G`), segment de revenu, produit de crédit (*debt_consolidation*, *credit_card*, *wedding*, etc.) et répartition géographique par État américain.
- **Performance des modèles ECL IFRS 9 :** comparaison entre le modèle *LR Retail* et *LR Retail + Macro* via la courbe ROC (AUC), la courbe d'étalonnage par décile, les indices de stabilité (PSI/CSI) et l'explicabilité des variables (Importance & valeurs SHAP).
- **Perspectives & impact macroéconomique :** intégration des variables FRED (Inflation / `cpi_index`, taux de chômage, taux d'intérêt Fed Funds, PIB) et simulation des ECL selon les scénarios *Baseline* (4,30 M), *Adverse* (4,77 M) et *Severe*.
- **Tests de résistance du modèle (Stress Testing) :** analyse en cascade (*Waterfall*) de l'impact d'un choc sévère (+50 % sur la PD et les ECL), identification des grades et produits les plus sensibles et mesure du capital consommé.

## Filtres interactifs

- Période temporelle (Année, Mois, Jour)
- Grade de notation interne (`A` à `G`)
- État géographique (`addr_state`)
- Produit de crédit (`purpose`)
- Type de modèle (`LR Retail` vs `LR Retail + Macro`)
- Scénario macroéconomique (`Baseline`, `Adverse`, `Severe`)

## Architecture & Technologies

- **Extraction & Stockage :** SQL Server (`sqlcmd`), Databricks Delta Lake (architecture en étoile : `fact_metrics` et 11 tables de dimensions `dim_client`, `dim_product`, `dim_rating`, `dim_risk`, `dim_behavior`, `dim_credit_history`, `dim_employment`, `dim_geography`, `dim_loan_status`, `dim_date`, `dim_macro`).
- **Ingénierie des données & ML :** Databricks (Spark SQL, PySpark, Python `pandas_datareader` pour l'API FRED, calcul des scores SHAP, PSI/CSI).
- **Business Intelligence :** Microsoft Power BI Desktop, Power Query, DAX avancé, navigation dynamique multi-pages et visuels financiers personnalisés.

## Structure du dépôt

```text
BI-Analytics-Risque-Credit-IFRS9-Forward-Looking/
│
├── Dashboard-Preview/
│   ├── 1 - Apercu niveau direction.jpg
│   ├── 2 - Analyse du risque de credit.jpg
│   ├── 3 - Performance des modeles ECL IFRS 9.jpg
│   ├── 4 - Perspectives et impact macroeconomique.jpg
│   └── 5 - Tests de resistance du modele.jpg
│
├── Data-Engineering-Databricks/
│   ├── 01_extract_sqlserver.sh
│   ├── 02_cleaning_and_star_schema.sql
│   ├── 03_data_preparation_pyspark.py
│   └── 04_macro_fred_ingestion.py
│
└── README.md
```

---

**Projet :** Pilotage du Risque de Crédit IFRS 9 (Forward-Looking)  
**Outils :** SQL Server, Databricks (PySpark / Delta Lake), Python (FRED API), Microsoft Power BI Desktop  
**Périmètre des données :** Portefeuille Lending Club (2018) & Séries Macroéconomiques FRED
**Projet :** Pilotage du Risque de Crédit IFRS 9 (Forward-Looking)  
**Outils :** SQL Server, Databricks (PySpark / Delta Lake), Python (FRED API), Microsoft Power BI Desktop  
**Périmètre des données :** Portefeuille Lending Club (2018) & Séries Macroéconomiques FRED
