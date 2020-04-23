---
--- Drop the entire DB (for development environments only)
---

drop procedure if exists create_release;
drop function if exists create_release;
drop procedure if exists add_data; --old
drop procedure if exists add_core_data;
drop procedure if exists commit_release;

drop materialized view if exists historial_data; -- typo
drop materialized view if exists historial_data_preview; -- typo

drop materialized view if exists historical_data;
drop materialized view if exists historical_data_preview;
drop materialized view if exists current_data;
drop materialized view if exists current_data_preview;

drop table if exists core_data;
drop table if exists core_data_changelog;
drop table if exists release;
drop table if exists state_info;
drop table if exists temp_data;

drop table if exists schema_info;

