--- populate tables

-- sample releases
insert into release (push_time, shift_lead,  is_daily_commit, is_preview, commit_note) values
	(now() - interval '3 days' - interval '7 hours', 'ek', true, false, 'normal publish'),
	(now() - interval '2 days' - interval '12 hours', 'ek', false, false, 'normal push'),
	(now() - interval '2 days' - interval '7 hours', 'ek', true, false, 'normal publish');
	
-- NY:
insert into core_data (release_id, state_name, as_of, is_daily_commit,
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values
	(1, 'NY', '4/13/20', true, 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(2, 'NY', '4/14/20', false, 195031, 283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(3, 'NY', '4/14/20', true, 202208, 296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 1, 2, null);
	
-- FL: skipped...
-- TX: skipped...

-- WA:
insert into core_data (release_id, state_name, as_of, is_daily_commit, 
					positive, negative, deaths, total, grade,
					last_update_time, last_checked_time, checker, double_checker, public_notes) 
	values	
	(1, 'WA', '4/13/20', true, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(2, 'WA', '4/14/20', false, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 1, 2, null),
	(3, 'WA', '4/14/20', true, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 1, 2, null);
	
