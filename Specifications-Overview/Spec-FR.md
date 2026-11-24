# Spécifications fonctionnelles – Pilotage du Risque de Crédit IFRS 9 (Forward-Looking)

## 1. Présentation du projet

Ce projet vise à mettre en place une solution analytique et décisionnelle complète dédiée à l'évaluation, au suivi et à la simulation prospective (**Forward-Looking**) du **risque de crédit sous la norme IFRS 9**.

Il permet d'extraire, de nettoyer, de centraliser et de modéliser des données de prêts (portefeuille Lending Club) croisées avec des indicateurs macroéconomiques officiels (**FRED**). Les résultats permettent de calculer les pertes de crédit attendues (**ECL**), d'évaluer la consommation en fonds propres (**RWA / CET1**), de comparer les modèles de notation (**LR Retail vs LR Retail + Macro**) et de réaliser des tests de résistance (*Stress Testing*) pour éclairer les décisions de gestion des risques.

## 2. Objectifs métier

L’objectif général est d’automatiser la chaîne de traitement du risque de crédit IFRS 9, de l'ingestion des données brutes jusqu’à leur restitution dans des tableaux de bord décisionnels interactifs.

Les objectifs spécifiques sont :

- **O1 – Extraction & Ingestion :** automatiser l'extraction des données de prêts depuis SQL Server et l'ingestion des séries macroéconomiques FRED dans Databricks.
- **O2 – Préparation & Qualité :** nettoyer, typer et filtrer 100 % des données brutes (gestion des valeurs nulles, suppression des incohérences, périmètre 2018).
- **O3 – Modélisation en étoile :** structurer un entrepôt analytique fiable autour d'une table de faits (`fact_metrics`) et de 11 tables de dimensions.
- **O4 – Modélisation Quantitative (PD / ECL) :** entraîner et comparer les modèles de Probabilité de Défaut (*LR Retail* vs *LR Retail + Macro*) et calculer les pertes attendues (ECL).
- **O5 – Stress Testing Forward-Looking :** simuler l'impact des scénarios macroéconomiques (*Baseline*, *Adverse*, *Severe*) sur les ECL et les fonds propres.
- **O6 – Reporting :** restituer 100 % des indicateurs prudentiels et de performance dans un tableau de bord Power BI multi-pages.

## 3. Périmètre fonctionnel et processus

Le dispositif couvre six étapes principales :

1. **Extraction des données sources :** export des données de crédits depuis SQL Server (`sqlcmd`) vers un volume Databricks.
2. **Nettoyage et préparation :** typage des variables, traitement des valeurs manquantes, filtrage du périmètre d'étude (année 2018) et création d'identifiants uniques via hachage SHA-256.
3. **Enrichissement macroéconomique :** collecte via API Python (`pandas_datareader` / FRED) des indicateurs clés (taux de chômage, indice des prix `cpi_index`, taux directeur Fed Funds, PIB) et lissage des séries.
4. **Modélisation analytique (Star Schema) :** construction des tables de dimensions (`dim_client`, `dim_product`, `dim_rating`, `dim_risk`, `dim_macro`, etc.) et de la table centrale `fact_metrics` sous Delta Lake.
5. **Modélisation du risque (IFRS 9) :** classification des prêts par Stage (1, 2, 3), entraînement des modèles de régression logistique (PD), calcul des métriques de validation (AUC, Gini, KS, PSI/CSI, SHAP) et simulation des chocs macroéconomiques.
6. **Reporting décisionnel :** création d'un rapport Power BI interactif structuré en 5 vues métier et techniques.

## 4. Indicateurs clés de performance (KPI)

Les indicateurs suivis dans les tableaux de bord comprennent :

| KPI | Définition / règle de calcul | Valeur / Cible |
|---|---|---:|
| Total RWA | Somme des actifs pondérés par les risques | 317,04 M\$ |
| Densité des RWA | Total RWA / Total EAD × 100 | 69,65 % |
| Ratio CET1 | Fonds propres de base (CET1) / Total RWA × 100 | 17,23 % (Cible ≥ 10,5 %) |
| Exigence en fonds propres | Total RWA × 8 % (exigence minimale Bâle III) | 25,36 M\$ |
| Total EAD | Exposition totale au moment du défaut (`out_prncp`) | 455,18 M\$ |
| Total ECL | Pertes de crédit attendues (`PD × LGD × EAD`) | 8,12 M\$ |
| Coût du risque | Total ECL / Total EAD × 100 | 1,78 % |
| Ratio de couverture | Provisions ECL / Encours en défaut (Stage 3) × 100 | 74,98 % |
| Pouvoir discriminant (AUC / Gini) | Aire sous la courbe ROC / `2 × AUC − 1` | 0,772 / 54,34 % (Cible AUC > 0,75) |
| Stabilité du modèle (PSI) | Population Stability Index entre échantillons | 0,00063 (Cible < 0,10) |

## 5. Architecture des données et sources

### Sources de données

| Source | Description | Accès |
|---|---|---|
| SQL Server (`Risk_Basel3`) | Base relationnelle contenant le portefeuille de prêts bruts (`dbo.Loan_Databricks`) | Extraction CSV via `sqlcmd` |
| API FRED (Federal Reserve) | Séries temporelles macroéconomiques (`UNRATE`, `CPIAUCSL`, `FEDFUNDS`, `GDP`) | Ingestion Python (`pandas_datareader`) |
| Databricks Delta Lake | Entrepôt de données centralisé (Star Schema `IFRS_9_credit_risk`) | Lecture / Écriture SQL & PySpark |

### Qualité des données

Les contrôles portent sur six dimensions :

- **Complétude :** filtrage des enregistrements sans profession (`emp_title`), sans durée d'emploi (`n/a`) ou sans statut de vérification, et comblement (*forward-fill*) des valeurs nulles du PIB (`gdp`).
- **Exactitude :** conversion stricte des formats numériques (remplacement des virgules par des points) et normalisation des dates (`issue_d`, `last_pymnt_d`).
- **Cohérence :** alignement temporel entre les dates d'octroi des prêts et les indicateurs macroéconomiques mensuels.
- **Unicité :** génération de clés techniques déterministes via hachage cryptographique `SHA-256` et `DENSE_RANK()` pour chaque dimension.
- **Fraîcheur :** mise à jour orchestrée par pipeline Databricks et actualisation des tables Delta.
- **Traçabilité :** conservation des versions intermédiaires (`loan_v0`, `loan_vs`, `loan_v1`, `dim_macro_v0`) pour l'auditabilité des transformations.

## 6. Règles de gestion

| ID | Règle | Description | Statut |
|---|---|---|---|
| RG-PER-001 | Périmètre d'étude | Seuls les prêts émis en **2018** avec un historique de crédit débutant entre **2010 et 2015** et un statut vérifié sont retenus. | Validé |
| RG-STG-001 | Classification IFRS 9 (Stages) | **Stage 3** : prêts en défaut (`Charged Off`, `Default`) ; **Stage 2** : prêts en retard (`Late`) ; **Stage 1** : prêts sains (`Current`, `Fully Paid`). | Validé |
| RG-CAL-001 | Calcul de l'EAD et des pertes | L'exposition au défaut (`EAD`) correspond au capital restant dû (`out_prncp`) ; la perte constatée correspond à `funded_amnt − total_rec_prncp`. | Validé |
| RG-MAC-001 | Traitement macroéconomique | Application d'un *Forward-Fill* (`LAST_VALUE`) sur le PIB trimestriel pour l'aligner sur une granularité mensuelle et calcul d'une moyenne mobile sur 2 mois. | Validé |
| RG-MOD-001 | Évaluation des modèles PD | Comparaison systématique entre le modèle interne (*LR Retail*) et le modèle prospectif (*LR Retail + Macro*) via AUC, KS, Brier Score et PSI/CSI. | Validé |
| RG-STR-001 | Scénarios Forward-Looking | Pondération et simulation des pertes attendues (ECL) selon trois scénarios économiques : *Baseline*, *Adverse* et *Severe* (+50 % choc PD/ECL). | Validé |
| RG-SEC-001 | Pseudonymisation | Remplacement des identifiants clients directs par une clé hachée (`member_hash`) et un identifiant technique séquentiel (`member_id`). | Validé |

## 7. Valeur ajoutée du projet

Le dispositif met à disposition une architecture Data & Risque complète et des tableaux de bord interactifs permettant de :

- Piloter les indicateurs prudentiels Bâle III / IFRS 9 (RWA, CET1, exigence en fonds propres, coût du risque).
- Suivre la répartition des encours et la migration du risque entre les **Stages 1, 2 et 3**.
- Analyser la sensibilité du portefeuille selon les grades internes (`A` à `G`), les produits de crédit et les États géographiques.
- Mesurer l'apport des variables macroéconomiques (inflation, chômage, taux d'intérêt, PIB) dans la prédiction du défaut.
- Expliquer les décisions des modèles grâce à l'analyse d'importance des variables et des valeurs **SHAP**.
- Quantifier l'impact d'un scénario économique dégradé (*Stress Test*) sur les provisions (ECL) et la consommation de capital.

---

**Projet :** Pilotage du Risque de Crédit IFRS 9 (Forward-Looking)  
**Technologies :** SQL Server, Databricks (PySpark / Delta Lake), Python (FRED API), Microsoft Power BI

