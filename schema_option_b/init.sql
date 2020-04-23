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


--- a record of the output of a shift (called 'commits' in the engineering doc)
create table release
(
	release_id serial primary key,
	previous_release_id int references release(release_id),
	push_time timestamptz null,
	shift_lead varchar(2) not null,
	shift_date date not null,
	shift_num int not null,
	commit_note varchar(1000),
	is_daily_commit boolean not null,
	is_preview boolean not null
);

-- core data from spreadsheet (called 'states' in the engineering doc)
create table core_data
(
	-- context fields
	release_id int not null references release(release_id),
	state_name varchar(2) not null,
	as_of date not null, -- (called date in engineering doc)
	shift_num int not null, -- added to enable unique index
	is_preview boolean, -- added to support unique index

	-- data fields
	positive int,
	negative int,
	deaths int,
	total int,
	grade char(1),

	-- notes
	source_notes varchar(1000),
	public_notes varchar(1000)
);

create unique index ix_release_state_asof on core_data (release_id, state_name, as_of);
create unique index ix_state_asof_shift_preview on core_data (state_name, as_of, shift_num, is_preview);

-- changelog table
create table core_data_changelog
(
	-- context fields
	release_id int not null references release(release_id),
	state_name varchar(2) not null,
	as_of date not null, -- (called date in engineering doc)
	shift_num int not null,

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

create unique index ix_release_state_asof_changelog on core_data_changelog (release_id, state_name, as_of);


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

-- the history
create materialized view historical_data
as
select D.*
from core_data D
join release R on R.release_id = D.release_id
where R.is_preview = false and R.is_daily_commit = true
order by as_of, state_name;

-- the history for preview
create materialized view historical_data_preview
as
select D.*
from core_data D
join release R on R.release_id = D.release_id
where R.is_daily_commit = true
order by as_of, state_name;

-- the current values
create materialized view current_data
as
select D.*
from core_data D
join
(
	select max(release_id) as release_id
	from release
	where is_preview = false
) X on X.release_id = D.release_id
order by D.state_name;

-- the current values for preview
create materialized view current_data_preview
as
select D.*
from core_data D
join
(
	select max(release_id) as release_id
	from release
) X on X.release_id = D.release_id
order by D.state_name;


---
--- Stored Procs to control access
---

-- create a new release
create procedure create_release(in p_shift_lead varchar(2), 
			in p_shift_date date, in p_shift_num int, in p_is_daily_commit boolean, 
			in p_commit_note varchar(1000),
			inout p_release_id int) 
language plpgsql
as $$
declare
	previous_id int;
begin

	select max(R.release_id) into previous_id 
	from release R
	where R.shift_date = p_shift_date and R.shift_num = p_shift_num;

	insert into release (previous_release_id, shift_lead, shift_date, shift_num, commit_note, is_daily_commit, is_preview) 
		values (previous_id, p_shift_lead, p_shift_date, p_shift_num, p_commit_note, p_is_daily_commit, true);
	
	p_release_id := lastval();
end;
$$;

-- add data from temporary table to release
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
		positive, negative, deaths, total, grade,
		source_notes, public_notes)
	values (p_release_id, rec.state_name, 
		release_record.shift_date, release_record.shift_num, true,
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade,
		rec.source_notes, rec.public_notes);

  	insert into core_data_changelog (release_id, state_name, 
	    as_of, shift_num, 
		positive, negative, deaths, total, grade,
		last_update_time, last_checked_time, checker, double_checker,
		private_notes, source_notes, public_notes)
	values (p_release_id, rec.state_name, 
		release_record.shift_date, release_record.shift_num,
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade,
		rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker,
		rec.private_notes, rec.source_notes, rec.public_notes);
  end loop;
  
end;
$$;


-- release to public
create procedure commit_release(in p_release_id int, p_push_time timestamptz)
language plpgsql
as $$
declare
	release_record record;
begin

	select * into release_record from release where release_id = p_release_id;

	if release_record is null then
		raise Exception 'Invalid p_release_id %', p_release_id;
	end if;
	if not release_record.is_preview then
		raise Exception 'Cannot release results twice';
	end if;

	if p_push_time is null then
		p_push_time := CURRENT_TIMESTAMP;
	end if;

	begin
		delete from core_data where release_id != release_record.previous_release_id;
		update core_data set is_preview = false where release_id = p_release_id;
		update release set push_time = p_push_time, is_preview = false where release_id = p_release_id;

		refresh materialized view historical_data;
		refresh materialized view historical_data_preview;
		refresh materialized view current_data;
		refresh materialized view current_data_preview;

	end;
end;
$$;
