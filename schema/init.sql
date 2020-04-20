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

--- data entry staff
create table staff
(
	staff_id serial primary key,
	code varchar(10) not null,
	staff_name varchar(100) not null,
	email varchar(100),
	cell_phone varchar(20),
	can_push boolean not null default(false),
	can_publish boolean not null default(false)
);

--- locations we track (ie - states)
create table location
(
	location_name char(2) primary key not null,
	full_name varchar(100) not null
);

--- a record of the output of a shift
create table release
(
	release_id serial primary key,
	created_at timestamptz not null,
	created_by int not null references staff(staff_id),
	release_date date not null, -- date that the update is for (same as as-of)
	release_time time not null, -- time that shift normally publishes
	shift_num int not null, -- 1=morning,2=afternoon,3=evneing.
	released_at timestamptz, -- when the data was released to the public
	is_released boolean not null, -- true if data has been released to public
	is_revision boolean not null, -- true if it is revising public data
    is_publish boolean not null, -- true for 2nd shift only
	release_note varchar(1000) not null
);

-- core data from spreadsheet
--   location_name + as_ok + revision must be unique.
--   as_of is the same as the release's as_of but included to eliminate the need to join in the batch
--   date_rev_key is a redundant field to make the views simpler.
--      it contains as_of + revision started as YYYYMMDDXX where XX = revision 
create table core_data
(
	-- context fields
	core_data_id serial primary key,
	release_id int not null references release(release_id),
	location_name char(2) not null references location(location_name),
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
	updated_at timestamptz not null,
	checked_at timestamptz not null,
	checked_by int not null references staff(staff_id),
	double_checked_by int not null references staff(staff_id)
);

create unique index ix_location_key on core_data (location_name, date_rev_key);
create unique index ix_asof_revision on core_data (location_name, as_of, revision);

---
--- Views
---

-- all the history that has been released
create materialized view historial_data
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true and R.is_publish = true
	group by location_name, as_of
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key
order by as_of, D.location_name;

-- history including preview (if any) for QC
create materialized view historial_data_preview
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true 
	group by location_name, as_of
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key
order by as_of, D.location_name;

-- current values
create materialized view current_data
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	where R.is_released = true 
	group by location_name
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key
order by D.location_name;

-- current values including preview (if any) for QC
create materialized view current_data_preview
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join release R on R.release_id = D.release_id
	group by location_name
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key;

---
--- Stored Procs to control access
---

-- create a new release
create procedure create_release(in p_staff_id int, in p_release_date date, in p_release_time time, in p_shift_num int, 
							  in p_is_revision bool, in p_is_publish bool, inout xid int)
language plpgsql
as $$
begin
  if p_shift_num <= 3 then
	if p_shift_num != 2 and p_is_publish == true then
		raise Exception 'Only shift #2 is allowed to publish';
	end if;
	if  p_is_revision == true then
		raise Exception 'Shift numbers 1-3 cannot be revisions';
	end if;
  else
	if p_is_revision == false then
		raise Exception 'Shift numbers above 3 must be revisions';
	end if;
  end if;

  insert into release (created_by, created_at, release_date, release_time, shift_num, is_released, is_revision, is_publish) 
    values (p_staff_id, now(), p_release_date, p_release_time, p_shift_num, false, p_is_revision, p_is_publish)
  returning xid;
end;
$$;

-- add data from temporary table to release
create procedure add_data(in p_release_id int, in p_table_name varchar(100))
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
					positive, negative, deaths, total, grade,
			
					updated_at, checked_at, checked_by, double_checked_by, public_notes) 
		values (p_release_id, rec%location_name, date_rev_key, rec%as_of, version_num, 
		   
			-- data fields --
			rec%positive, rec%negative, rec%deaths, rec%total, rec%grade,

			rec%updated_at, rec%checked_at, rec%checked_by, rec%double_checked_by, rec%public_notes);
  end loop;
  
end;
$$;

-- release to public
create procedure release_changes(in p_staff_id int, in p_release_id int)
language plpgsql
as $$
begin
	update release set is_released = true, released_at = now()
	where release_id = p_release_id and is_released = false;
end;
$$;


