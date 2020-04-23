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
	push_time timestamptz not null,
	shift_lead varchar(2) not null,
	commit_note varchar(1000),
	is_daily_commit boolean not null,
	is_preview boolean not null
);

-- core data from spreadsheet (called 'states' in the engineering doc)
create table core_data
(
	-- context fields
	release_id int not null references release(release_id),
	state_name varchar(2) not null references state_info(state_name),
	as_of date not null, -- (called date in engineering doc)
	is_daily_commit boolean not null, -- added to enable unique index
	
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

create unique index ix_release_state_asof on core_data (release_id, state_name, as_of, is_daily_commit);

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
where R.is_preview = false and R.is_daily_commit = True
order by as_of, state_name;

-- the history for preview
create materialized view historical_data_preview
as
select D.*
from core_data D
join release R on R.release_id = D.release_id
where R.is_daily_commit = True
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
			p_is_daily_commit boolean, in p_commit_note varchar(1000), inout xid int)
language plpgsql
as $$
begin

	delete from core_data D
	where D.release_id in (select release_id from release where is_preview = true);

	insert into release (shift_lead, push_time, commit_note, is_daily_commit, is_preview) 
		values (p_shift_lead, now(), p_commit_note, p_is_daily_commit, true);
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
begin

  select * into release_record from release where release_id = p_release_id;

  if release_record is null then
    raise Exception 'Invalid p_release_id %', p_release_id;
  end if;
  if not release_record.is_preview then
	raise Exception 'Cannot update results after release';
  end if;

  delete from core_data where release_id = p_release_id;

  for rec in execute concat('select * from ', p_table_name) 
  loop
  	insert into core_data (release_id, state_name, as_of, is_daily_commit,

		-- data fields
		positive, negative, deaths, total, grade,

		last_update_time, last_checked_time, checker, double_checker,
		private_notes, source_notes, public_notes)

	values (p_release_id, rec.state_name, date(rec.last_update_time), release_record.is_daily_commit,  
		
		-- data fields --
		rec.positive, rec.negative, rec.deaths, rec.total, rec.grade,

		rec.last_update_time, rec.last_checked_time, rec.checker, rec.double_checker,
		rec.private_notes, rec.source_notes, rec.public_notes);
  end loop;
  
end;
$$;


-- release to public
create procedure commit_release(in p_release_id int, in p_push_time timestamptz)
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

	begin
		update release set is_preview = false where release_id = p_release_id;
		delete from core_data where release_id != p_release_id and is_daily_commit = false;
	end;

	refresh materialized view historical_data;
	refresh materialized view historical_data_preview;
	refresh materialized view current_data;
	refresh materialized view current_data_preview;

end;
$$;
