-- add recovered to core data

-- 1. add the column to the name
do $$
begin
	if not exists (
			select * 
			from information_schema.columns 
			where table_name = 'core_data' and column_name = 'recovered') then
	begin
		alter table core_data add column recovered int;
		alter table core_data_changelog add column recovered int;
		alter table temp_data add column recovered int;
	end;
end if;
end;
$$;

-- 2. update the add_data proc
create procedure add_core_data(in p_release_id int, in p_table_name varchar(100))
language plpgsql
as $$

declare
  release_record record;
  rec record;
begin

  select * into release_record from release where release_id = p_release_id;

  if release_record is null then
    raise Exception 'Invalid p_release_id %', p_release_id;
  end if;
  if not release_record.is_preview then
	raise Exception 'Cannot update results after release';
  end if;

  delete from core_data where release_id = p_release_id;
  delete from core_data_changelog where release_id = p_release_id;

  for rec in execute concat('select * from ', p_table_name) 
  loop
  	insert into core_data (release_id, state_name, 
	  	as_of, shift_num, is_preview,
		positive, negative, deaths, total, grade, recovered,
		source_notes, public_notes)
	values (p_release_id, rec.state_name, 
		release_record.shift_date, release_record.shift_num, true,
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade, rec.recovered,
		rec.source_notes, rec.public_notes);

  	insert into core_data_changelog (release_id, state_name, 
	    as_of, shift_num, 
		positive, negative, deaths, total, grade, recovered,
		last_update_time, last_checked_time, checker, double_checker,
		private_notes, source_notes, public_notes)
	values (p_release_id, rec.state_name, 
		release_record.shift_date, release_record.shift_num,
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade, rec.recovered,
		rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker,
		rec.private_notes, rec.source_notes, rec.public_notes);
  end loop;
  
end;
$$;


