/*
=========================================================================================================
DDL Script: Create Bronze Tables 
=========================================================================================================
Script Purpose:
   This script creates tables in the 'bronze' schema, dropping existing tables if they are already exist.
   Run this script to re-define the DDL scturture of 'bronze' Tables
=========================================================================================================

*/

CREATE DATABASE DataWarehouse;
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info(
    cst_id INT,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_material_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE
);
DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info(
    prd_id INT,
    prd_key VARCHAR(50),
    prd_nm  VARCHAR(50),
    prd_cost INT,
    prd_line VARCHAR(50),
    prd_start_dt TIMESTAMP,
    prd_end_dt TIMESTAMP
);

DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details(
    sls_ord_num VARCHAR(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id INT,
    sls_order_dt INT,
    sls_ship_dt INT,
    sls_due_dt INT,
    sls_sales INT,
    sls_quantity INT,
    sls_price INT
);

DROP TABLE IF EXISTS bronze.erp_loc_a101;
CREATE TABLE bronze.erp_loc_a101(
    cid VARCHAR(50),
    cntry VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.erp_cust_az12;
CREATE TABLE bronze.erp_cust_az12(
    cid VARCHAR(50),
    bdate DATE,
    gen VARCHAR
);

DROP TABLE IF EXISTS bronze.erp_px_cat_g1v2;
CREATE TABLE bronze.erp_px_cat_g1v2(
    id VARCHAR(50),
    cat VARCHAR(50),
    subcat VARCHAR(50),
    maintenance VARCHAR(10)
);

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
	start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN 
  start_time := clock_timestamp();
  RAISE NOTICE '====================';
  RAISE NOTICE 'Loading Bronze Table';
  RAISE NOTICE '====================';
  RAISE NOTICE '--------------------';
  RAISE NOTICE 'Loading CRM Tables';
  RAISE NOTICE '--------------------';

  start_time := clock_timestamp();
  RAISE NOTICE '>> Trancating table: bronze.crm_cust_info';
  TRUNCATE TABLE bronze.crm_cust_info;
  RAISE NOTICE '>> Inserting data into: bronze.crm_cust_info';
  COPY bronze.crm_cust_info
  FROM '/tmp/cust_info.csv'
  WITH (
     FORMAT csv,
     HEADER true,
     DELIMITER ','
);
  end_time := clock_timestamp();
  SELECT COUNT(*) INTO v_count FROM bronze.crm_cust_info;
    RAISE NOTICE 'bronze.crm_cust_info loaded: % rows', v_count;
    RAISE NOTICE 'Load Duration: % sec', 
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
  

  TRUNCATE TABLE bronze.crm_prd_info;
  COPY bronze.crm_prd_info
  FROM '/tmp/prd_info.csv'
  WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ','
);

  SELECT COUNT(*) INTO v_count FROM bronze.crm_prd_info;
    RAISE NOTICE 'bronze.crm_prd_info loaded: % rows', v_count;
  

  TRUNCATE TABLE bronze.crm_sales_details;
  COPY bronze.crm_sales_details
  FROM '/tmp/sales_details.csv'
  WITH(
    FORMAT csv,
    HEADER true,
    DELIMITER ','
);
  SELECT COUNT(*) INTO v_count FROM bronze.crm_sales_details;
    RAISE NOTICE 'bronze.crm_sales_details loaded: % rows', v_count;

 
  RAISE NOTICE '--------------------';
  RAISE NOTICE 'Loading ERP Tables';
  RAISE NOTICE '--------------------';
  TRUNCATE bronze.erp_loc_a101;
  COPY bronze.erp_loc_a101
  FROM '/tmp/LOC_A101.csv'
  WITH(
     FORMAT csv,
 	 HEADER true,
	 DELIMITER ','
);
  SELECT COUNT(*) INTO v_count FROM bronze.erp_loc_a101;
    RAISE NOTICE 'bronze.erp_loc_a101 loaded: % rows', v_count;


  TRUNCATE bronze.erp_cust_az12;
  COPY bronze.erp_cust_az12
  FROM '/tmp/CUST_AZ12.csv'
  WITH(
     FORMAT csv,
	 HEADER true,
	 DELIMITER ','
);
  SELECT COUNT(*) INTO v_count FROM bronze.erp_cust_az12;
    RAISE NOTICE 'erp_cust_az12 loaded: % rows', v_count;


  TRUNCATE bronze.erp_px_cat_g1v2;
  COPY bronze.erp_px_cat_g1v2
  FROM '/tmp/PX_CAT_G1V2.csv'
  WITH(
     FORMAT csv,
	 HEADER true,
	 DELIMITER ','
);
  SELECT COUNT(*) INTO v_count FROM bronze.erp_px_cat_g1v2;
    RAISE NOTICE 'bronze.erp_px_cat_g1v2 loaded: % rows', v_count;
	
  end_time := clock_timestamp();
    RAISE NOTICE 'Total Load Duration: % sec', 
       ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
  EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '-----------';
		RAISE NOTICE 'ERROR OCCURED DURING BRONZE LAYER';
		RAISE NOTICE 'Error message: %', SQLERRM;
        RAISE NOTICE 'Error code: %', SQLSTATE;
	    RAISE NOTICE '-----------';
END;
$$;

CALL bronze.load_bronze();
