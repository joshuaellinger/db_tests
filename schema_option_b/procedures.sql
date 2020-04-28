
---
--- Stored Procs to control access
---

-- publish a new batch
create procedure publish_batch(in p_shift_lead varchar(2), in p_published_at timestamptz,
			in p_is_daily_commit boolean, in p_is_revision boolean, 
			in p_batch_note varchar(1000))
language plpgsql
as $$
declare
	xid int;
begin

	insert into batch (shift_lead, published_at, batch_note, is_daily_commit, is_revision) 
		values (p_shift_lead, p_published_at, p_batch_note, p_is_daily_commit, p_is_revision);
	xid := lastval();

	insert into core_data 
	select xid as batch_id, *
	from core_data_preview;

	delete from core_data_preview;

	refresh materialized view historical_data;
	refresh materialized view historical_data_preview;
	refresh materialized view current_data;
	refresh materialized view current_data_preview;

end;
$$;
