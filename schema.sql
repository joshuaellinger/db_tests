
create table staff
(
	staff_id serial primary key,
	code varchar(10) not null,
	staff_name varchar(100) not null,
	email varchar(100),
	cellphone varchar(20),
	can_push boolean not null default(false),
	can_publish boolean not null default(false)
);

create table location
(
	location_name char(2) primary key not null,
	full_name varchar(100) not null
);

create table batch
(
	batch_id serial primary key,
	entered_at timestamptz not null,
	entered_by int references staff(staff_id),
	release_date date not null,
	release_time time not null,
	shift_num int not null,
	is_released boolean not null, -- true if data has been released to public
	is_revision boolean not null, -- true if it is revising public data
    is_publish boolean not null, -- true for 2nd shift only
	batch_notes varchar(10000)
);

create table core_data
(
	location_name char(2) references location(location_name),
	date_rev_key int not null,
	batch_id int not null references batch(batch_id),
	as_of date not null,
	revision int not null default(1),
	positive int,
	negative int,
	recovered int,
	deaths int,
	total int,
	grade char(1),
	updated_at timestamptz not null,
	checked_at timestamptz not null,
	checked_by int references staff(staff_id),
	double_checked_by int references staff(staff_id),
	public_notes varchar(10000),
	primary key (location_name, date_rev_key)
);

--- populate tables

-- just a couple of people
insert into staff (code, staff_name, email, can_push, can_publish) values
   ('je','Joshua Ellinger', 'joshuaellinger@gmail.com', false, false),
   ('ek','Elliot Klug', 'careeningspace@gmail.com', true, true);
 
 -- just a couple of states
 insert into location (location_name, full_name) values
  ('NY', 'New York'),  ('FL', 'Florida'),  ('TX', 'Texas'), ('WA', 'Washington');

-- simulate a normal day + a revision on the following morning b/c CA came in too late
insert into batch (entered_at, entered_by, release_date, release_time, shift_num, is_released, is_revision, is_publish, batch_notes) values
	(now() - interval '3 days' - interval '7 hours', 2, '4/14/20', '5:00', 2, true, false, true, 'normal publish'),
	(now() - interval '2 days' - interval '12 hours', 2, '4/14/20', '12:00', 1, true, false, false, 'normal push'),
	(now() - interval '2 days' - interval '7 hours', 2, '4/14/20', '5:00', 2, true, false, true, 'normal publish'),
	(now() - interval '2 days' - interval '0 hours', 2, '4/14/20', '23:00', 3, true, false, false, 'normal push'),
	(now() - interval '1 days' - interval '16 hours', 2, '4/14/20', '5:00', 2, true, true, true, 'revision for west coast'),
	(now() - interval '1 days' - interval '12 hours', 2, '4/15/20', '12:00', 1, false, false, false, 'preview for shift 1');
	
-- NY: pretend update at 3:30 every day.
insert into core_data (batch_id, location_name, date_rev_key, as_of, revision, positive, negative, recovered, deaths, total, grade,
					   updated_at, checked_at, checked_by, double_checked_by, public_notes) 
	values
	(1, 'NY', 2020041302, '4/13/20', 2, 195031,	283326,	null, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(2, 'NY', 2020041401, '4/14/20', 1, 195031,	283326,	null, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(3, 'NY', 2020041402, '4/14/20', 2, 202208,	296935,	null, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 1, 2, null),
	(4, 'NY', 2020041403, '4/14/20', 3, 202208,	296935,	null, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 23:30-04', 1, 2, null),
	(6, 'NY', 2020041501, '4/15/20', 1, 202208,	296935,	null, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-15 11:30-04', 1, 2, null);
	
-- FL: skipped...
-- TX: skipped...

-- WA: pretend it comes in at 6:30PM on 4/14 after the cutoff then during shift 1 on the 4/15
insert into core_data (batch_id, location_name, date_rev_key, as_of, revision, positive, negative, recovered, deaths, total, grade,
					   updated_at, checked_at, checked_by, double_checked_by, public_notes) 
	values	
	(1, 'WA', 2020041302, '4/13/20', 2, 10411, 83391, null, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(2, 'WA', 2020041401, '4/14/20', 1, 10411, 83391, null, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(3, 'WA', 2020041402, '4/14/20', 2, 10411, 83391, null, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 1, 2, null),
	(4, 'WA', 2020041403, '4/14/20', 3, 10538, 83391, null, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 1, 2, 'nothing new as-of 5pm'),
	(5, 'WA', 2020041404, '4/14/20', 4, 10538, 83391, null, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 1, 2, 'data arrived late'),
	(6, 'WA', 2020041501, '4/15/20', 1, 10694, 112160, null, 541, 122854, 'C', '2020-04-15 10:30-04', '2020-04-15 11:30-04', 1, 2, null);
	
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
	join batch B on B.batch_id = D.batch_id
	where B.is_released = true and B.is_publish = true
	group by location_name, as_of
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key
order by D.as_of, D.location_name;

-- history including preview (if any) for QC
create materialized view historial_data_preview
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join batch B on B.batch_id = D.batch_id
	where  B.is_publish = true
	group by location_name, as_of
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key
order by D.as_of, D.location_name;

-- current values
create materialized view current_data
as
select D.*
from core_data D
join
(
	select location_name, max(date_rev_key) as date_rev_key 
	from core_data D
	join batch B on B.batch_id = D.batch_id
	where B.is_released = true 
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
	join batch B on B.batch_id = D.batch_id
	group by location_name
) X on X.location_name = D.location_name and X.date_rev_key = D.date_rev_key

---
--- Stored Procs to control access
---

-- create a new batch
create procedure create_batch(in p_staff_id int, in p_release_date date, in p_release_time time, in p_shift_num int, 
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

  insert into batch (staff_id, release_date, release_time, shift_num, is_released, is_revision, is_publish) 
    values (p_staff_id, p_release_date, p_release_time, p_shift_num, false, p_is_revision, p_is_publish)
  returning xid;
end;
$$;

-- add data to batch
create procedure add_data(in p_batch_id int, in p_table_name varchar(100))
language plpgsql
as $$

declare
  batch_record record;
  rec record;
  version_num int;
  date_rev_key int;
begin
  select * into batch_record
  from batch
  where batch_id = p_batch_id;

  if batch_record%is_released == true then
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

	insert into core_data (batch_id, location_name, date_rev_key, as_of, revision, 
					positive, negative, recovered, deaths, total, grade,
					updated_at, checked_at, checked_by, double_checked_by, public_notes) 
		values (p_batch_id, rec%location_name, date_rev_key, rec%as_of, version_num, 
		   rec%positive, rec%negative, rec%recovered, rec%deaths, rec%total, rec%grade,
		   rec%updated_at, rec%checked_at, rec%checked_by, rec%double_checked_by, rec%public_notes);
  end loop;
  
end;
$$;

-- release batch to public
create procedure release_changes(in p_staff_id int, in p_batch_id int)
language plpgsql
as $$
begin
	update batch set is_released = true, entered_at = now(), entered_by = p_staff_id 
	where batch_id = p_batch_id and is_released = false;
end;
$$;


