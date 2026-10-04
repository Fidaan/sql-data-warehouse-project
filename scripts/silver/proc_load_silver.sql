/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables.
        - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$ 
DECLARE
    v_count INT;
	start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN 
  start_time := clock_timestamp();
  RAISE NOTICE '====================';
  RAISE NOTICE 'Loading Silver Table';
  RAISE NOTICE '====================';
  RAISE NOTICE '--------------------';
  RAISE NOTICE 'Loading CRM Tables';
  RAISE NOTICE '--------------------';
 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.crm_cust_info';
 TRUNCATE TABLE silver.crm_cust_info;
 RAISE NOTICE '>> Inserting data into: silver.crm_cust_info';
 INSERT INTO silver.crm_cust_info(
       cst_id,
	   cst_key,
	   cst_firstname,
	   cst_lastname,
	   cst_marital_status,
	   cst_gndr,
	   cst_create_date)
 SELECT cst_id,
       cst_key,
       TRIM(cst_firstname) AS cst_firstname,
       TRIM(cst_lastname) AS cst_lastname,
       CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
       END AS cst_marital_status,
       CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
       END AS cst_gndr,
       cst_create_date
 FROM bronze.crm_cust_info;
 end_time := clock_timestamp();
  SELECT COUNT(*) INTO v_count FROM silver.crm_cust_info;
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);

 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.crm_prd_info';
 TRUNCATE TABLE silver.crm_prd_info;
 RAISE NOTICE '>> Inserting data into: silver.crm_prd_info';
 INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
 )
 SELECT 
 prd_id,
 -- Extracts the category prefix (e.g., 'AC-HE') and standardizes format by swapping hyphens for underscores
  REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    
 -- Strips off the category prefix to leave only the core product key starting from position 7
 SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS prd_key, -- LENGTH returns the total character count of the string
 prd_nm,
 -- Handles missing/null costs by defaulting them to 0
 COALESCE(prd_cost, 0) AS prd_cost,
 -- Maps coded product line letters ('M', 'R', etc.) to full readable descriptions, handling trailing spaces and lowercase inputs
 CASE UPPER(TRIM(prd_line)) -- CASE is ideal for categorical value mapping
     WHEN 'M' THEN 'Mountain'
     WHEN 'R' THEN 'Road'
     WHEN 'S' THEN 'Other Sales'
     WHEN 'T' THEN 'Touring'
      ELSE 'n/a'
 END AS prd_line,
    
 -- Casts timestamp/datetime values into a clean DATE format (YYYY-MM-DD). We use CAST to convert data type from one another 
 CAST(prd_start_dt AS DATE) AS prd_start_dt,
    
 -- Data enrichment: adding a value to your data. Calculates effective end date by taking the NEXT record's start date per product key and subtracting 1 day
 CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL '1 day' AS DATE) AS prd_end_dt
 FROM bronze.crm_prd_info;
 end_time := clock_timestamp();
 SELECT COUNT(*) INTO v_count FROM silver.crm_prd_info;
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);

 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.crm_sales_details';
 TRUNCATE TABLE silver.crm_sales_details;
 RAISE NOTICE '>> Inserting data into: silver.crm_sales_details';
 INSERT INTO silver.crm_sales_details(
         sls_ord_num,
         sls_prd_key,
         sls_cust_id,
         sls_order_dt,
         sls_ship_dt,
         sls_due_dt,
         sls_sales,
         sls_quantity,
         sls_price
 )
--Business rule: sales = quantity * price. Negative and zero are not allowed
--If Sales is negative, zero or null derive it using quantity and price
--If Price is zero or null, calculate is using sales and quantity
--If Price is negative, convert it to positive number 
 SELECT 
 sls_ord_num,
 sls_prd_key,
 sls_cust_id,
 CASE WHEN (sls_order_dt) = 0 OR LENGTH(sls_order_dt::text) != 8 THEN NULL 
     ELSE CAST(sls_order_dt::text AS DATE) 
 END sls_order_dt,
 CASE WHEN (sls_ship_dt) = 0 OR LENGTH(sls_ship_dt::text) != 8 THEN NULL 
     ELSE CAST(sls_ship_dt::text AS DATE) 
 END sls_ship_dt,
 CASE WHEN (sls_due_dt) = 0 OR LENGTH(sls_due_dt::text) != 8 THEN NULL 
     ELSE CAST(sls_due_dt::text AS DATE)
 END sls_due_dt,
 -- Business Rule: If sales is missing, <= 0, or inconsistent, calculate as price * quantity
 CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_price * ABS(sls_quantity) THEN ABS(sls_price) * ABS(sls_quantity)
     ELSE sls_sales
 END AS sls_sales,
 sls_quantity,
 -- Business Rule: If price is missing or <= 0, derive from sales / quantity. Otherwise convert to positive.
 CASE WHEN sls_price IS NULL OR sls_price <= 0  THEN ABS(sls_sales) / NULLIF(ABS(sls_quantity), 0)
    ELSE ABS(sls_price)
 END AS sls_price
 FROM bronze.crm_sales_details;
 end_time := clock_timestamp();
 SELECT COUNT(*) INTO v_count FROM silver.crm_sales_details;
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);

 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.erp_cust_az12';
 TRUNCATE TABLE silver.erp_cust_az12;
 RAISE NOTICE '>> Inserting data into: silver.erp_cust_az12';
 INSERT INTO silver.erp_cust_az12(cid, bdate, gen)
 SELECT 
 CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
     ELSE cid
 END AS cid,
 CASE WHEN bdate > CURRENT_DATE THEN NULL
     ELSE bdate
 END AS bdate,
 CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
     WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
	 ELSE 'n/a'
 END AS gen
 FROM bronze.erp_cust_az12; 
  end_time := clock_timestamp();
  SELECT COUNT(*) INTO v_count FROM silver.erp_cust_az12; 
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);

 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.erp_loc_a101';
 TRUNCATE TABLE silver.erp_loc_a101;
 RAISE NOTICE '>> Inserting data into: silver.erp_loc_a101';
 INSERT INTO silver.erp_loc_a101(
         cid,
         cntry 
) 
 SELECT 
 REPLACE(cid, '-', '') cid,
 CASE WHEN TRIM(cntry)= 'DE' THEN 'Germany'
     WHEN TRIM(cntry)= 'US' OR cntry='USA' THEN 'United States'
	 WHEN TRIM(cntry)= '' OR cntry IS NULL THEN 'n/a'
	 ELSE TRIM(cntry)
 END AS cntry
 FROM bronze.erp_loc_a101 loc;
 end_time := clock_timestamp();
  SELECT COUNT(*) INTO v_count FROM silver.erp_loc_a101 loc;
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);


 start_time := clock_timestamp();
 RAISE NOTICE '>> Truncating table: silver.erp_px_cat_g1v2';
 TRUNCATE TABLE silver.erp_px_cat_g1v2;
 RAISE NOTICE '>> Truncating table: silver.erp_px_cat_g1v2';
    
 INSERT INTO silver.erp_px_cat_g1v2 (
        id, cat, subcat, maintenance
    )
 SELECT 
    id, cat, subcat, maintenance
 FROM bronze.erp_px_cat_g1v2;
 end_time := clock_timestamp();
  SELECT COUNT(*) INTO v_count FROM silver.erp_px_cat_g1v2;
    RAISE NOTICE 'silver.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
 EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ERROR OCCURED DURING LOADING BRONZE LAYER';
    RAISE NOTICE 'Error Message: %', SQLERRM;
    RAISE NOTICE 'Error Number (State): %', SQLSTATE;
    RAISE NOTICE '==================================================';
END $$;

CALL silver.load_silver();
