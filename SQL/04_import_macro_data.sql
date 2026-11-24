-- ============================================================================
-- PROJET      : BI Analytics – Risque de Crédit IFRS 9 (Forward-Looking)
-- SCRIPT      : 04_import_macro_data.sql
-- DESCRIPTION : Préparation des indicateurs macroéconomiques FRED, gestion des 
--               valeurs manquantes du PIB (Forward-Fill) et lissage des séries 
--               temporelles pour la dimension dim_macro.
-- ============================================================================


-- ============================================================================
-- 1. PRÉPARATION ET STABILISATION INITIALE DES SÉRIES MACRO (DIM_MACRO_V0)
-- ============================================================================
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_macro_v0 AS

WITH base AS (
    SELECT
        CAST(date AS DATE) AS macro_date,
        unemployment_rate_pct,
        cpi_index,
        interest_rate_pct,
        gdp
    FROM IFRS_9_credit_risk.stg_macro
),

filled AS (
    SELECT
        *,
        -- --------------------------------------------------------------------
        -- 1.1 Imputation initiale des valeurs nulles du PIB (valeur précédente)
        -- --------------------------------------------------------------------
        COALESCE(gdp, LAG(gdp) OVER (ORDER BY macro_date)) AS gdp_filled
    FROM base
)

SELECT
    macro_date,
    unemployment_rate_pct,
    cpi_index,
    interest_rate_pct,
    gdp_filled AS gdp
FROM filled;


-- ============================================================================
-- 2. CONSTRUCTION DE LA DIMENSION MACROÉCONOMIQUE FINALE (DIM_MACRO)
-- ============================================================================
CREATE OR REPLACE TABLE IFRS_9_credit_risk.dim_macro AS

WITH ordered AS (
    SELECT
        CAST(macro_date AS DATE) AS macro_date,
        unemployment_rate_pct,
        cpi_index,
        interest_rate_pct,
        gdp
    FROM IFRS_9_credit_risk.dim_macro_v0
),

filled_gdp AS (
    SELECT
        *,
        -- --------------------------------------------------------------------
        -- 2.1 Propagation avant (Forward-Fill) du PIB trimestriel (standard bancaire)
        -- --------------------------------------------------------------------
        COALESCE(
            gdp,
            LAST_VALUE(gdp, true) OVER (
                ORDER BY macro_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            )
        ) AS gdp_filled
    FROM ordered
),

final AS (
    SELECT
        macro_date,
        unemployment_rate_pct,
        cpi_index,
        interest_rate_pct,

        -- PIB nettoyé et aligné mensuellement
        gdp_filled AS gdp,

        -- --------------------------------------------------------------------
        -- 2.2 Lissage du PIB via moyenne mobile sur 2 mois
        -- --------------------------------------------------------------------
        AVG(gdp_filled) OVER (
            ORDER BY macro_date
            ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
        ) AS gdp_smooth_2m

    FROM filled_gdp
)

SELECT *
FROM final;
