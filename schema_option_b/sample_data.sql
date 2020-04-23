do $$
declare
   release_id int;
begin


-- 4/13/20 afternoon shift
call create_release('ek', '4/13/20', 2, true, 'normal publish', release_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, now() - interval '3 days' - interval '7 hours');

-- 4/14/20 morning shift
call create_release('ek', '4/14/20', 1, false, 'normal push', release_id);

delete from temp_data;
insert into temp_data (state_name, 
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, now() - interval '2 days' - interval '12 hours');


-- 4/14/20 afternoon shift
call create_release('ek', '4/14/20', 2, true, 'normal publish', release_id);

delete from temp_data;
insert into temp_data (state_name, 
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 1, 2, null);

call add_core_data(release_id, 'temp_data');
call commit_release(release_id, now() - interval '2 days' - interval '7 hours');


end;
$$;

