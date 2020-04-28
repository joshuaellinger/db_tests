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


--- a record of the output of a shift
create table batch 
(
    batch_id serial primary key,
    --created_at timestamptz not null,
    published_at timestamptz,
    shift_lead varchar(100), -- design question: initials vs names
    batch_note varchar,
    is_daily_commit boolean not null,
    is_revision boolean not null
);

-- core data from spreadsheet
create table core_data
(
	-- context fields
    batch_id int not null references batch(batch_id),
	state_name varchar(2) not null references state_info(state_name),
	data_date date not null, -- (same as as_of)
	
	-- data fields
	positive int,
	negative int,
	deaths int,
	total int,
	grade char(1),

	-- data entry fields
	last_update_time timestamptz not null,
	last_checked_time timestamptz not null,
	checker varchar(100) not null,
	double_checker varchar(100) not null,
	private_notes varchar,
	source_notes varchar,
	public_notes varchar
);

-- no more than one state+data_date per batch
create unique index ix_batch_state_asof on core_data (batch_id, state_name, data_date);

-- core data from spreadsheet
create table core_data_preview
(
	-- context fields
	state_name varchar(2) not null references state_info(state_name),
	data_date date not null, -- (same as as_of)
	
	-- data fields
	positive int,
	negative int,
	deaths int,
	total int,
	grade char(1),

	-- data entry fields
	last_update_time timestamptz not null,
	last_checked_time timestamptz not null,
	checker varchar(100) not null,
	double_checker varchar(100) not null,
	private_notes varchar,
	source_notes varchar,
	public_notes varchar
);

-- no more than one state+data_date per batch
create unique index ix_preview_state_asof on core_data_preview (state_name, data_date);

