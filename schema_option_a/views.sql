---
--- Views
---

-- the history
create materialized view historical_data
as
select D.*
from core_data D
join 
(
    select D.state_name, D.data_date, max(D.batch_id) as batch_id
    from core_data D
    join batch B on B.batch_id = D.batch_id
    where not B.is_preview and B.is_daily_commit
    group by D.state_name, D.data_date
) B on B.batch_id = D.batch_id and B.data_date = D.data_date and D.state_name = B.state_name
order by D.data_date, D.state_name;

-- the history for preview
create materialized view historical_data_preview
as
select D.*
from core_data D
join 
(
    select D.state_name, D.data_date, max(D.batch_id) as batch_id
    from core_data D
    join batch B on B.batch_id = D.batch_id
    where B.is_daily_commit
    group by D.state_name, D.data_date
) B on B.batch_id = D.batch_id and B.data_date = D.data_date and D.state_name = B.state_name
order by D.data_date, D.state_name;

-- the current values
create materialized view current_data
as
select D.*
from core_data D
join 
(
    select D.state_name, max(D.batch_id) as batch_id
    from core_data D
    join batch B on B.batch_id = D.batch_id
    where not B.is_preview 
    group by D.state_name
) B on B.batch_id = D.batch_id and D.state_name = B.state_name
order by D.state_name;

-- the current values for preview
create materialized view current_data_preview
as
select D.*
from core_data D
join 
(
    select D.state_name, max(D.batch_id) as batch_id
    from core_data D
    join batch B on B.batch_id = D.batch_id
    group by D.state_name
) B on B.batch_id = D.batch_id and D.state_name = B.state_name
order by D.state_name;
