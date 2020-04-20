---
--- Drop the entire DB (for development environments only)
---

drop procedure if exists create_release;
drop procedure if exists add_data;
drop procedure if exists release_changes;

drop materialized view if exists historial_data;
drop materialized view if exists historial_data_preview;
drop materialized view if exists current_data;
drop materialized view if exists current_data_preview;

drop table if exists core_data;
drop table if exists release;
drop table if exists batch;
drop table if exists location;
drop table if exists staff;

drop table if exists schema_info;
