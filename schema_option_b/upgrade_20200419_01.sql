-- add recovered to core data
do $$
begin
if not exists (
		select * 
		from information_schema.columns 
		where table_name = 'core_data' and column_name = 'recovered') then
	alter table core_data add column recovered int;
	alter table core_data_preview add column recovered int;
end if;
end;
$$;
