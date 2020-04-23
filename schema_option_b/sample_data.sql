do $$
declare
   release_id int;
begin

 -- just a couple of states
 insert into state_info (state_name, full_name) values
  ('NY', 'New York'),  ('WA', 'Washington');

-- 4/13/20 afternoon shift
call create_release('ek', '4/13/20 17:00', 2, true, 'normal publish', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, '4/13/20 16:30:10');

-- 4/14/20 morning shift
call create_release('ek', '4/14/20 12:00', 1, false, 'normal push', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, '4/13/20 11:30:10');

-- 4/14/20 afternoon shift
call create_release('ek', '4/14/20 17:00', 2, true, 'normal publish', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 'cl', 'ek', null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 'cl', 'ek', null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, '4/14/20 16:30:10');

-- 4/14/20 revision to afternoon shift for west coast
call create_release('ek', '4/14/20 17:00', 2,  true, 'revision for west coast', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 'cl', 'ek', null),
	('WA', 10538, 83391, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 'cl', 'ek', 'data arrived late');

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, '4/14/20 20:30:10');

-- 4/14/20 evening shift
call create_release('ek', '4/14/20 23:00', 3, false, 'normal push', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 23:30-04', 'cl', 'ek', null),
	('WA', 10538, 83391, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 'cl', 'ek', 'nothing new as-of 5pm');

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, '4/14/20 22:30:10');

-- 4/15/20 morning shift (in preview)
call create_release('ek', '4/15/20 12:00', 1, false, 'preview', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-15 11:30-04', 'cl', 'ek', null),
	('WA', 10694, 112160, 541, 122854, 'C', '2020-04-15 10:30-04', '2020-04-15 11:30-04', 'cl', 'ek', null);

call add_core_data(release_id, 'temp_data');

--call commit_release(release_id, '4/15/20 10:30:10');


end;
$$;

