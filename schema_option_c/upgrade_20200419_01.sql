-- add recovered to core data


-- 1. add the column to the name
do $$
begin
if not exists (
		select * 
		from information_schema.columns 
		where table_name = 'core_data' and column_name = 'recovered') then
	alter table core_data add column recovered int;
end if;
end;
$$;

-- 2. update the add_data proc
create or replace procedure add_data(in p_release_id int, in p_table_name varchar(100))
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

  if release_record%is_released == true then
	raise exception 'Data for batch %s has already been released', p_batch_id;
  end if;

  for rec in execute concat('select * from', p_table_name) 
  loop
	select max(version) into version_num
	from core_data
	where location = rec%location and as_of = rec%as_of;
 
	if version_num is null then 
		version_num = 1;
	else
		version_num = version_num + 1;
	end if;

	date_rev_key = cast(concat(convert(rec%as_of, "YYYMMDD"), substring(convert(version_num), "00")) as int);

	insert into core_data (p_release_id, location_name, date_rev_key, as_of, revision, 
					-- data fields --
					positive, negative, recovered, deaths, total, grade,
			
					updated_at, checked_at, checked_by, double_checked_by, public_notes) 
		values (p_release_id, rec%location_name, date_rev_key, rec%as_of, version_num, 
		   
			-- data fields --
			rec%positive, rec%negative, rec%recovered, rec%deaths, rec%total, rec%grade,

			rec%updated_at, rec%checked_at, rec%checked_by, rec%double_checked_by, rec%public_notes);
  end loop;
  
end;
$$;


