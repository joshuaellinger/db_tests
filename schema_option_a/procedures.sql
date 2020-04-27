
---
--- Stored Procs to control access
---

-- create a new batch
create procedure create_batch(in p_shift_lead varchar(2), in p_created_at timestamptz,
			p_is_daily_commit boolean, in p_batch_note varchar(1000), inout xid int)
language plpgsql
as $$
begin

    -- remove any unpublished batchs (only one active preview at a time)
	delete from core_data D
	where D.batch_id in (select batch_id from batch where is_preview = true);
	delete from batch D where is_preview = true;
    
	insert into batch (shift_lead, created_at, batch_note, is_daily_commit, is_preview) 
		values (p_shift_lead, p_created_at, p_batch_note, p_is_daily_commit, true);
	xid := lastval();
end;
$$;


-- add data from temporary table to batch
create procedure add_core_data(in p_batch_id int, in p_table_name varchar(100))
language plpgsql
as $$

declare
  batch_record record;
  rec record;
begin

  select * into batch_record from batch where batch_id = p_batch_id;

  if batch_record is null then
    raise Exception 'Invalid batch_id %', p_batch_id;
  end if;
  if not batch_record.is_preview then
	raise Exception 'Cannot update results after batch';
  end if;

  delete from core_data where batch_id = p_batch_id;

  for rec in execute concat('select * from ', p_table_name) 
  loop
  	insert into core_data (batch_id, state_name, data_date,

		-- data fields
		positive, negative, deaths, total, grade,

		last_update_time, last_checked_time, checker, double_checker,
		private_notes, source_notes, public_notes)

	values (p_batch_id, rec.state_name, date(rec.last_update_time),  
		
		-- data fields --
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade,

		rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker,
		rec.private_notes, rec.source_notes, rec.public_notes);
  end loop;
  
end;
$$;


-- batch to public
create procedure commit_batch(in p_batch_id int, in p_published_at timestamptz)
language plpgsql
as $$
declare
	batch_record record;
begin

	select * into batch_record from batch where batch_id = p_batch_id;

	if batch_record is null then
		raise Exception 'Invalid batch_id %', p_batch_id;
	end if;
	if not batch_record.is_preview then
		raise Exception 'Cannot publish batch twice';
	end if;

	begin
		update batch set is_preview = false, published_at = p_published_at  where batch_id = p_batch_id;
		delete from core_data where batch_id != p_batch_id;
	end;

	refresh materialized view historical_data;
	refresh materialized view historical_data_preview;
	refresh materialized view current_data;
	refresh materialized view current_data_preview;

end;
$$;
