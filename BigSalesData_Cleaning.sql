-- ============================================================
--  BIG SALES DATA - Data Cleaning (Revised)
--  Prepared by : Laodi Antonius Sijabat
--  Project     : Self-Initiated Retail Sales Analysis
--  Date        : 2024
--  Revision    : AVG → MEDIAN per SKU, fallback → median per category
-- ============================================================


-- INSPECT RAW DATA

SELECT COUNT(*)                                                 AS total_rows       FROM Big_Sales_Data;
SELECT
    SUM(CASE WHEN Item_Weight    IS NULL THEN 1 ELSE 0 END)     AS null_weight,
    SUM(CASE WHEN Item_Visibility = 0    THEN 1 ELSE 0 END)     AS zero_visibility
FROM Big_Sales_Data;
SELECT Item_Fat_Content, COUNT(*) AS count                      FROM Big_Sales_Data GROUP BY Item_Fat_Content;


-- DATA CLEANING WITH CTE

CREATE VIEW cleaned_sales AS
WITH

-- Step 1: Median weight per SKU menggunakan PERCENTILE_CONT
-- (menghindari distorsi dari nilai pencilan dibanding AVG)
weight_median AS (
    SELECT
        Item_Identifier,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Item_Weight) AS median_weight
    FROM Big_Sales_Data
    WHERE Item_Weight IS NOT NULL
    GROUP BY Item_Identifier
),

-- Step 2: Fallback median weight per Item_Type (bukan global)
-- Logis karena berat produk bervariasi antar kategori
-- contoh: Snack Foods ~12.85kg, Dairy ~13.30kg
category_weight_median AS (
    SELECT
        Item_Type,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Item_Weight) AS category_median
    FROM Big_Sales_Data
    WHERE Item_Weight IS NOT NULL
    GROUP BY Item_Type
),

-- Step 3: Median visibility per SKU dari record non-zero
-- Visibility = 0 bukan data valid, bukan sinyal bisnis
visibility_median AS (
    SELECT
        Item_Identifier,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Item_Visibility) AS median_visibility
    FROM Big_Sales_Data
    WHERE Item_Visibility > 0
    GROUP BY Item_Identifier
),

-- Step 4: Imputasi weight dan visibility
imputed AS (
    SELECT
        b.Item_Identifier,
        b.Item_Type,

        -- Weight: SKU median → category median (bukan global)
        COALESCE(
            b.Item_Weight,
            wm.median_weight,
            cwm.category_median
        )                                                       AS Item_Weight,

        -- Visibility: ganti 0 dengan median SKU dari outlet lain
        CASE
            WHEN b.Item_Visibility = 0 THEN vm.median_visibility
            ELSE b.Item_Visibility
        END                                                     AS Item_Visibility,

        b.Item_Fat_Content,
        b.Item_MRP,
        b.Outlet_Identifier,
        b.Outlet_Establishment_Year,
        b.Outlet_Size,
        b.Outlet_Location_Type,
        b.Outlet_Type,
        b.Item_Outlet_Sales

    FROM Big_Sales_Data b
    LEFT JOIN weight_median          wm  ON b.Item_Identifier = wm.Item_Identifier
    LEFT JOIN category_weight_median cwm ON b.Item_Type       = cwm.Item_Type
    LEFT JOIN visibility_median      vm  ON b.Item_Identifier = vm.Item_Identifier

    -- Filter hanya untuk keamanan kode, bukan untuk menghapus sinyal bisnis
    -- Data ini tidak memiliki baris penjualan nol/null (14,204 valid semua)
    WHERE b.Item_Identifier   IS NOT NULL
      AND b.Outlet_Identifier IS NOT NULL
),

-- Step 5: Standardisasi label dan tambah kolom turunan
standardized AS (
    SELECT
        Item_Identifier,
        ROUND(Item_Weight, 3)                                   AS Item_Weight,

        CASE
            WHEN LOWER(TRIM(Item_Fat_Content)) IN ('low fat','lf')  THEN 'Reduced Fat'
            WHEN LOWER(TRIM(Item_Fat_Content)) IN ('regular','reg') THEN 'Full Fat'
            ELSE TRIM(Item_Fat_Content)
        END                                                     AS Fat_Content,

        ROUND(Item_Visibility, 6)                               AS Item_Visibility,
        TRIM(Item_Type)                                         AS Item_Type,

        CASE
            WHEN Item_Type IN ('Fruits and Vegetables','Meat','Seafood') THEN 'Fresh & Produce'
            WHEN Item_Type = 'Dairy'                                     THEN 'Dairy & Eggs'
            WHEN Item_Type IN ('Baking Goods','Breads','Breakfast',
                               'Canned','Starchy Foods')                 THEN 'Grocery Staples'
            WHEN Item_Type IN ('Frozen Foods','Snack Foods')             THEN 'Frozen & Snacks'
            WHEN Item_Type IN ('Hard Drinks','Soft Drinks')              THEN 'Beverages'
            ELSE 'Non-Food Items'
        END                                                     AS Item_Category,

        ROUND(Item_MRP, 2)                                      AS Item_MRP,

        CASE
            WHEN Item_MRP < 50  THEN 'Budget'
            WHEN Item_MRP < 100 THEN 'Mid-Range'
            WHEN Item_MRP < 150 THEN 'Premium'
            ELSE                     'Luxury'
        END                                                     AS MRP_Bracket,

        Outlet_Identifier,

        CASE
            WHEN Outlet_Type = 'Supermarket Type1' THEN 'Chain Supermarket'
            WHEN Outlet_Type = 'Supermarket Type2' THEN 'Mid-Scale Market'
            WHEN Outlet_Type = 'Supermarket Type3' THEN 'Premium Supermarket'
            WHEN Outlet_Type = 'Grocery Store'     THEN 'Grocery Outlet'
        END                                                     AS Outlet_Type,

        CASE
            WHEN Outlet_Location_Type = 'Tier 1' THEN 'Metro District'
            WHEN Outlet_Location_Type = 'Tier 2' THEN 'Suburban District'
            WHEN Outlet_Location_Type = 'Tier 3' THEN 'Regional District'
        END                                                     AS Location_District,

        CASE
            WHEN Outlet_Size = 'High' THEN 'Large'
            ELSE TRIM(Outlet_Size)
        END                                                     AS Outlet_Size,

        Outlet_Establishment_Year,
        (2024 - Outlet_Establishment_Year)                      AS Outlet_Age,
        ROUND(Item_Outlet_Sales, 2)                             AS Sales_Amount

    FROM imputed
)

SELECT * FROM standardized;


-- VALIDASI HASIL

SELECT COUNT(*)                                                 AS total_clean_rows FROM cleaned_sales;
SELECT
    SUM(CASE WHEN Item_Weight       IS NULL THEN 1 ELSE 0 END)  AS null_weight,
    SUM(CASE WHEN Item_Visibility   IS NULL THEN 1 ELSE 0 END)  AS null_visibility,
    SUM(CASE WHEN Item_Visibility   = 0     THEN 1 ELSE 0 END)  AS zero_visibility,
    SUM(CASE WHEN Fat_Content       IS NULL THEN 1 ELSE 0 END)  AS null_fat,
    SUM(CASE WHEN Location_District IS NULL THEN 1 ELSE 0 END)  AS null_district,
    SUM(CASE WHEN Sales_Amount      IS NULL THEN 1 ELSE 0 END)  AS null_sales
FROM cleaned_sales;

SELECT Fat_Content,       COUNT(*) AS count FROM cleaned_sales GROUP BY Fat_Content;
SELECT Outlet_Type,       COUNT(*) AS count FROM cleaned_sales GROUP BY Outlet_Type;
SELECT Location_District, COUNT(*) AS count FROM cleaned_sales GROUP BY Location_District;
SELECT Item_Category,     COUNT(*) AS count FROM cleaned_sales GROUP BY Item_Category ORDER BY count DESC;
