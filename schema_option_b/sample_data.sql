do $$
declare
   batch_id int;
begin

 -- just a couple of states
if not exists (select * from state_info) then
	insert into state_info (state_name, full_name) values ('NY', 'New York'),  ('WA', 'Washington');
end if;

-- 4/13/20 afternoon shift
delete from core_data_preview;
insert into core_data_preview (state_name, data_date,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', '2020-04-13', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', '2020-04-13', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);


call publish_batch('ek', '2020-04-13 16:30 EST', true, false, 'normal publish');

-- 4/14/20 morning shift
delete from core_data_preview;
insert into core_data_preview (state_name, data_date,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', '2020-04-14', 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	('WA', '2020-04-14', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null);


call publish_batch('ek', '2020-04-14 11:30 EST', false, false, 'normal push');

-- 4/14/20 afternoon shift (in preview)
delete from core_data_preview;
insert into core_data_preview (state_name, data_date,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	('NY', '2020-04-14', 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 1, 2, null),
	('WA', '2020-04-14', 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 1, 2, null);

call publish_batch('ek', '2020-04-14 16:30 EST', true, false, 'normal push');

end;
$$;

