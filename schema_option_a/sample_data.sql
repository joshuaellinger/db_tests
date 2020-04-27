do $$
declare
   batch_id int;
begin

 -- just a couple of states
if not exists (select * from state_info) then
	insert into state_info (state_name, full_name) values ('NY', 'New York'),  ('WA', 'Washington');
end if;

-- 4/13/20 afternoon shift
call create_batch('ek', '2020-04-13 13:30 EST', true, false, 'normal publish', batch_id);

delete from temp_data;
insert into temp_data (state_name,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);

call add_core_data(batch_id, 'temp_data');
call commit_batch(batch_id, '2020-04-13 16:30 EST');

-- 4/14/20 morning shift
call create_batch('ek', '2020-04-14 9:30 EST', false, false, 'normal push', batch_id);

delete from temp_data;
insert into temp_data (state_name, 
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);

call add_core_data(batch_id, 'temp_data');
call commit_batch(batch_id, '2020-04-14 11:30 EST');


-- 4/14/20 afternoon shift (in preview)
call create_batch('ek', '2020-04-14 13:30 EST', true, false, 'normal publish', batch_id);

delete from temp_data;
insert into temp_data (state_name, 
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 1, 2, null),
	('WA', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 1, 2, null);

call add_core_data(batch_id, 'temp_data');

--call commit_batch(batch_id, '2020-04-14 16:30 EST');


end;
$$;

