---
--- Drop the entire DB (for development environments only)
---

drop procedure if exists add_data; --old
drop procedure if exists add_core_data; --old
drop procedure if exists create_release; --old
drop procedure if exists commit_release; --old
drop procedure if exists create_batch; --old
drop procedure if exists commit_batch; --old
drop procedure if exists publish_batch;


drop materialized view if exists historial_data; --typo
drop materialized view if exists historial_data_preview; --tyop
drop materialized view if exists historical_data;
drop materialized view if exists historical_data_preview;
drop materialized view if exists current_data;
drop materialized view if exists current_data_preview;

drop view if exists core_data_combined; --typo

drop table if exists core_data_changelog; --old

drop table if exists core_data;
drop table if exists core_data_preview;
drop table if exists temp_data; --old
drop table if exists release; --old
drop table if exists batch;
drop table if exists state_info;

drop table if exists schema_info;
