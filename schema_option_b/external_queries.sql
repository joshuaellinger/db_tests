/* Gets the latest DAILY batch_id for each state as-of Z = 2020-04-13. */
SELECT state_name, MAX(D.batch_id) as batch_id
FROM core_data D 
JOIN batch B ON D.batch_id = B.batch_id
WHERE D.data_date = '2020-04-13' AND B.is_daily_commit 
GROUP BY D.state_name;
    
/* What were all core_data on date Z? For this example, say Z is 2020-03-20.
 Get the latest DAILY data for 2020-03-20 by state. This incorporates historical edits, 
 showing the latest one. (Expected: NY 175, PA 131.) */
SELECT D.* 
FROM core_data D
join (
	SELECT D2.state_name, MAX(D2.batch_id) as batch_id
	FROM core_data D2 
	JOIN batch B ON B.batch_id = D2.batch_id
	WHERE D2.data_date = '2020-03-20' AND B.is_daily_commit
	GROUP BY D2.state_name
) AS X on X.state_name = D.state_name and X.batch_id = D.batch_id;

/* What are all core_data right now? For this example, let's say today's date is 2020-03-21.
Get the latest data for today's date, by state. Should be: NY 190, PA 150. 
Resolves edit conflicts. Works for any date, including today. 
*/
SELECT D.* 
FROM core_data D
join (
	SELECT D2.state_name, MAX(D2.batch_id) as batch_id
	FROM core_data D2 
	JOIN batch B ON B.batch_id = D2.batch_id
	WHERE D2.data_date = '2020-03-21'
	GROUP BY D2.state_name
) AS X on X.state_name = D.state_name and X.batch_id = D.batch_id;

/* What are all core_data right now? Don't assume we know the last day.
Get the latest data for today's date, by state. Should be: NY 190, PA 150. 
Resolves edit conflicts. Works for any date, including today. 
*/
SELECT D.* 
FROM core_data D
JOIN (
	SELECT D2.state_name, MAX(D2.batch_id) as batch_id
	FROM core_data D2 
	JOIN batch B ON B.batch_id = D2.batch_id
	GROUP BY D2.state_name
) AS X on X.state_name = D.state_name and X.batch_id = D.batch_id;

/* What is the daily commit history for state Y? For this example, say for NY. 
This also shows the history of edits to daily commits. */
SELECT D.*, B.published_at 
FROM core_data D
JOIN batch B ON B.batch_id = D.batch_id
WHERE D.state_name = 'NY' and B.is_daily_commit
ORDER BY B.published_at;

/* Website: What's the latest day we have published data on? */
SELECT date(max(B.published_at)) as last_date
FROM batch B
WHERE not B.is_revision;

/* QC: What states have stale data for today? */
SELECT D.state_name, D.data_date 
FROM core_data D
JOIN batch B ON B.batch_id = D.batch_id
WHERE B.is_daily_commit and date(B.published_at) != D.data_date
ORDER BY D.state_name;
