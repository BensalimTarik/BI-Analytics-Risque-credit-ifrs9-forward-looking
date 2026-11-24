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
        
        -- =========================
        -- FILL NULL GDP (stabilisation série)
        -- =========================
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

-- Mise à jour pour dim_macro finale

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
        
        -- =====================================
        -- FORWARD FILL GDP (standard banking)
        -- =====================================
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

        -- cleaned GDP
        gdp_filled AS gdp,

        -- =====================================
        -- optional: GDP smoothing (rolling mean)
        -- =====================================
        AVG(gdp_filled) OVER (
            ORDER BY macro_date
            ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
        ) AS gdp_smooth_2m

    FROM filled_gdp
)

SELECT *
FROM final;


