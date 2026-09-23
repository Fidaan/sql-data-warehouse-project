/*
Create Database and Schemas
・ニニニニニニニニニ
Script Purpose:
This script creates a new database named DataWarehouse' after checking if it already exists.
If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas within the database: 'bronze', 'silver', and gold'
WARNING:
Running this script will drop the entire 'DataWarehouse' database if it exists.
All data in the database will be permanently deleted. Proceed with caution and ensure you have proper backups before running this script.
*/
-- Drop and recreate the 'Datawarehouse' database
IF EXISTS (SELECT 1 FROM sys. databases WHERE name = Datawarehouse')
BEGIN
ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE Datawarehouse;
END;


-- Create the 'Datawarehouse' database
CREATE DATABASE DataWarehouse;
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
