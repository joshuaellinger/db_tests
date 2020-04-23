-- add recovered to core data


-- 1. add the column to the name
do $$
begin
if not exists (
		select * 
		from information_schema.columns 
		where table_name = 'core_data' and column_name = 'recovered') then
	alter table core_data add column recovered int;
	alter table temp_data add column recovered int;
end if;
end;
$$;

-- 2. update the add_data proc
-- add data from temporary table to release
create procedure add_core_data(in p_release_id int, in p_table_name varchar(100))
language plpgsql
as $$

declare
  release_record record;
  rec record;
  version_num int;
  date_rev_key int;
begin
  select * into release_record
  from release
  where release_id = p_release_id;

  if release_record is null then
    raise Exception 'Invalid p_release_id %', p_release_id;
  end if;

  if release_record.is_released then
	raise exception 'Data for batch % has already been released', p_batch_id;
  end if;

  delete from core_data where release_id = p_release_id;

  for rec in execute concat('select * from ', p_table_name) 
  loop
	select max(version) into version_num
	from core_data
	where state_name = rec.state_name and as_of = rec.as_of;
 
	if version_num is null then 
		version_num = 1;
	else
		version_num = version_num + 1;
	end if;

	date_rev_key = cast(concat(convert(rec.as_of, "YYYMMDD"), substring(convert(version_num), "00")) as int);

	insert into core_data (release_id, state_name, date_rev_key, as_of, revision, 

					-- data fields --
					positive, negative, deaths, total, grade, recovered,

					last_update_time, last_checked_time, checker, double_checker, 
					private_notes, source_notes, public_notes) 
		values (p_release_id, rec.state_name, date_rev_key, rec.as_of, version_num, 
		   
			-- data fields --
			rec.positive, rec.negative, rec.deaths, rec.total, rec.grade, rec.recovered,

			rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker, 
			rec.private_notes, rec.source_notes, rec.public_notes);
  end loop;
  
end;
$$;


