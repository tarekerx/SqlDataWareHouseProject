/*
===================================
Create Database an Schemas
===================================

Script Purpose:
  This script creats a new database ma,ed 'DataWarehouse' after checking if it already exsist.
  If it exsists the data base wil be dropped then recreated. Further more, The sript sets up three schemas
  within the data base: branze, silver, gold

WARNING:
  Running this script will  drop the entire  'DataWarehouse' database if it exists.
  All data in the database will be permanently deleted. Proceed with caution
  and ensure you ahve proper backups before tunnning this script.

*/

USE master;
go

if exists(select 1 from sys.databases where name = 'DataWareHouse')
begin
alter DATABASE DataWareHouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
Drop DATABASE DataWareHouseL;
END:
go

-- Create DataWareHouse database
create DATABASE DataWareHouse;
go

use DataWareHouse
go

create schema bronze;
go
create schema silver;
go
create schema gold;
go
