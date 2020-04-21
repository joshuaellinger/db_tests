--- populate tables


 -- just a couple of states
 insert into state_info (state_name, full_name) values
  ('NY', 'New York'),  ('FL', 'Florida'),  ('TX', 'Texas'), ('WA', 'Washington');

-- simulate a normal day + a revision on the following morning b/c CA came in too late
insert into release (created_at, shift_lead, release_date, release_time, shift_num, is_released, is_revision, is_publish, release_note) values
	(now() - interval '3 days' - interval '7 hours', 'ek', '4/14/20', '5:00', 2, true, false, true, 'normal publish'),
	(now() - interval '2 days' - interval '12 hours', 'ek', '4/14/20', '12:00', 1, true, false, false, 'normal push'),
	(now() - interval '2 days' - interval '7 hours', 'ek', '4/14/20', '5:00', 2, true, false, true, 'normal publish'),
	(now() - interval '2 days' - interval '0 hours', 'ek', '4/14/20', '23:00', 3, true, false, false, 'normal push'),
	(now() - interval '1 days' - interval '16 hours', 'ek', '4/14/20', '5:00', 2, true, true, true, 'revision for west coast'),
	(now() - interval '1 days' - interval '12 hours', 'ek', '4/15/20', '12:00', 1, false, false, false, 'preview for shift 1');

update release set released_at = created_at + interval '15 minutes' where is_released = True;
	
-- NY: pretend update at 3:30 every day.
insert into core_data (release_id, state_name, date_rev_key, as_of, revision, positive, negative, deaths, total, grade,
					   updated_at, checked_at, checked_by, double_checked_by, public_note) 
	values
	(1, 'NY', 2020041302, '4/13/20', 2, 195031,	283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	(2, 'NY', 2020041401, '4/14/20', 1, 195031,	283326, 10056, 478357, 'A', '2020-04-13 15:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	(3, 'NY', 2020041402, '4/14/20', 2, 202208,	296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 16:30-04', 'cl', 'ek', null),
	(4, 'NY', 2020041403, '4/14/20', 3, 202208,	296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-14 23:30-04', 'cl', 'ek', null),
	(6, 'NY', 2020041501, '4/15/20', 1, 202208,	296935, 10834, 499143, 'A', '2020-04-14 15:30-04', '2020-04-15 11:30-04', 'cl', 'ek', null);
	
-- FL: skipped...
-- TX: skipped...

-- WA: pretend it comes in at 6:30PM on 4/14 after the cutoff then during shift 1 on the 4/15
insert into core_data (release_id, state_name, date_rev_key, as_of, revision, positive, negative, deaths, total, grade,
					   updated_at, checked_at, checked_by, double_checked_by, public_note) 
	values	
	(1, 'WA', 2020041302, '4/13/20', 2, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	(2, 'WA', 2020041401, '4/14/20', 1, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 11:30-04', 'cl', 'ek', null),
	(3, 'WA', 2020041402, '4/14/20', 2, 10411, 83391, 508, 93802, 'C', '2020-04-13 18:30-04', '2020-04-14 16:30-04', 'cl', 'ek', null),
	(4, 'WA', 2020041403, '4/14/20', 3, 10538, 83391, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 'cl', 'ek', 'nothing new as-of 5pm'),
	(5, 'WA', 2020041404, '4/14/20', 4, 10538, 83391, 516, 93929, 'C', '2020-04-14 18:30-04', '2020-04-14 23:30-04', 'cl', 'ek', 'data arrived late'),
	(6, 'WA', 2020041501, '4/15/20', 1, 10694, 112160, 541, 122854, 'C', '2020-04-15 10:30-04', '2020-04-15 11:30-04', 'cl', 'ek', null);
	
