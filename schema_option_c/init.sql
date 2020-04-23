---
--- Create the initial DB schema (DO NOT EDIT, use upgrades instead)
---

---
--- Tables
---

-- schema revision tracking
create table schema_info
(
	schema_info_id int not null,
	applied_at timestamptz not null,
	label varchar(100),
	content_checksum varchar(100)
);


--- meta-data on states
create table state_info
(
	state_name char(2) primary key not null,
	full_name varchar(100) not null
);

--- a record of the output of a shift
create table release
(
	release_id serial primary key,
	created_at timestamptz not null,
	shift_lead varchar(2) not null,
	release_date date not null, -- date that the update is for (same as as-of)
	release_time time not null, -- time that shift normally publishes
	shift_num int not null, -- 1=morning,2=afternoon,3=evening.
	released_at timestamptz, -- when the data was released to the public
	is_released boolean not null, -- true if data has been released to public
	is_revision boolean not null, -- true if it is revising public data
    is_publish boolean not null, -- true for 2nd shift only
	commit_note varchar(1000) not null
);

-- core data from spreadsheet
--   state_name + as_ok + revision must be unique.
--   as_of is the same as the release's as_of but included to eliminate the need to join in the batch
--   date_rev_key is a redundant field to make the views simpler.
--      it contains as_of + revision started as YYYYMMDDXX where XX = revision 
create table core_data
(
	-- context fields
	core_data_id serial primary key,
	release_id int not null references release(release_id),
	state_name char(2) not null references state_info(state_name),
	as_of date not null,
	date_rev_key int not null,
	revision int not null default(1),

	-- data fields
	positive int,
	negative int,
	deaths int,
	total int,
	grade char(1),

	-- notes
	public_note varchar(1000),
	private_note varchar(1000),
	qc_note varchar(1000),

	-- data entry fields
	last_update_time timestamptz not null,
	last_checked_time timestamptz not null,
	checker varchar(2) not null,
	double_checker varchar(2) not null,
	private_notes varchar(1000),
	source_notes varchar(1000),
	public_notes varchar(1000)
);

create unique index ix_state_date_rev_key on core_data (state_name, date_rev_key);
create unique index ix_state_asof_revision on core_data (state_name, as_of, revision);

-- temp table for loading data
create table temp_data
(
	-- context fields
	state_name varchar(2) not null,

	-- data fields
	positive int,
	negative int,
	deaths int,
	total int,
	grade char(1),

	-- data entry fields
	last_update_time timestamptz not null,
	last_checked_time timestamptz not null,
	checker varchar(2) not null,
	double_checker varchar(2) not null,
	private_notes varchar(1000),
	source_notes varchar(1000),
	public_notes varchar(1000)
);

---
--- Views
---

-- all the history that has been released
create materialized view historical_data
as
select D.*
from core_data D
join
(
	select state_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true and R.is_publish = true
	group by state_name, as_of
) X on X.state_name = D.state_name and X.date_rev_key = D.date_rev_key
order by as_of, D.state_name;

-- history including preview (if any) for QC
create materialized view historical_data_preview
as
select D.*
from core_data D
join
(
	select state_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true 
	group by state_name, as_of
) X on X.state_name = D.state_name and X.date_rev_key = D.date_rev_key
order by as_of, D.state_name;

-- current values
create materialized view current_data
as
select D.*
from core_data D
join
(
	select state_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true 
	group by state_name
) X on X.state_name = D.state_name and X.date_rev_key = D.date_rev_key
order by D.state_name;

-- current values including preview (if any) for QC
create materialized view current_data_preview
as
select D.*
from core_data D
join
(
	select state_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	group by state_name
) X on X.state_name = D.state_name and X.date_rev_key = D.date_rev_key;

---
--- Stored Procs to control access
---

-- create a new release
create procedure create_release(in p_shift_lead varchar(2), in p_release_date date, in p_release_time time, 
		in p_shift_num int, 
		in p_is_revision bool, in p_is_publish bool, 
		in p_commit_note varchar(1000),
		inout xid int)
language plpgsql
as $$
begin
  if p_shift_num <= 3 then
	if p_shift_num != 2 and p_is_publish then
		raise Exception 'Only shift #2 is allowed to publish';
	end if;
	if  p_is_revision then
		raise Exception 'Shift numbers 1-3 cannot be revisions';
	end if;
  else
	if not p_is_revision then
		raise Exception 'Shift numbers above 3 must be revisions';
	end if;
  end if;

  insert into release (shift_lead, created_at, release_date, release_time, shift_num, 
  		is_released, is_revision, is_publish, commit_note) 
    values (p_shift_lead, now(), p_release_date, p_release_time, p_shift_num, 
		false, p_is_revision, p_is_publish, p_commit_note);

  xid := lastval();
end;
$$;

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
	select max(revision) into version_num
	from core_data
	where state_name = rec.state_name and as_of = release_record.release_date;
 
	if version_num is null then 
		version_num := 1;
	else
		version_num := version_num + 1;
	end if;

	date_rev_key = cast(concat(to_char(release_record.release_date, 'YYYYMMDD'), substring(to_char(version_num, '00'), 2,3)) as int);

	insert into core_data (release_id, state_name, date_rev_key, as_of, revision, 

					-- data fields --
					positive, negative, deaths, total, grade,

					last_update_time, last_checked_time, checker, double_checker, 
					private_notes, source_notes, public_notes) 
		values (p_release_id, rec.state_name, date_rev_key, release_record.release_date, version_num, 
		   
			-- data fields --
			rec.positive, rec.negative, rec.deaths, rec.total, rec.grade,

			rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker, 
			rec.private_notes, rec.source_notes, rec.public_notes);

  end loop;
  
end;
$$;

-- release to public
create procedure commit_release(in p_release_id int, in p_released_time timestamptz)
language plpgsql
as $$
declare
  release_record record;
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

	if p_released_time is null then
		p_released_time := CURRENT_TIMESTAMP;
	end if;

	update release set is_released = true, released_at = p_released_time
	where release_id = p_release_id and is_released = false;

	refresh materialized view historical_data;
	refresh materialized view historical_data_preview;
	refresh materialized view current_data;
	refresh materialized view current_data_preview;

end;
$$;


