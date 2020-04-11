from loguru import logger
import psycopg2

from shared import database

def connect_to_db():

    logger.info("test connection")
    try:
        conn = database.connect_to_db()
        conn.close()
        logger.info("  success")
    except:
        logger.exception("  failed")


def main():
    connect_to_db()

if __name__ ==  "__main__":
    main()


"""

DO $$
DECLARE
  tn varchar(100) = '';
BEGIN 

SELECT tablename into tn 
FROM pg_catalog.pg_tables 
WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';

raise info 'table name is %', tn;

if tn is null then
create table RawChecks
(
	State char(2)
);
end if;

END $$;

--SELECT * FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
SELECT table_name, column_name, ordinal_position, data_type, character_maximum_length FROM information_schema.columns WHERE table_schema = 'public';
"""
