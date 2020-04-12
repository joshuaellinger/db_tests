from loguru import logger
from typing import Dict, List, Tuple
from configparser import ConfigParser
import os
import psycopg2

from datetime import date, datetime
import pandas as pd
import numpy as np

class Database:

    def __init__(self, params: Dict):
        self.conn = psycopg2.connect(**params)
        self.cursor = None        
        self.schema = None
        self.dtype_map = None


    def close(self):
        if self.cursor != None: self.cursor.close()
        self.cursor = None
        self.conn.close()
        self.conn = None


    def execute(self, smt: str, *args, **kwargs) -> None:
        " run a command against the DB"
        conn = self.conn
        try:
            if self.cursor: raise Exception("cursor is still in-use")
            self.cursor = conn.cursor()
            if len(args) > 0:
                self.cursor.execute(smt, args)
            else:
                self.cursor.execute(smt, kwargs)
            conn.commit()
        except Exception:
            logger.error(f"execute failed: {smt}")    
            raise Exception("execute failed")
        finally:
            self.cursor.close()
            self.cursor = None


    def _query(self, smt: str, args: Tuple, kwargs: Dict):
        " query (generic, returns a cursor)"
        conn = self.conn
        try:
            if self.cursor: raise Exception("cursor is still in-use")
            self.cursor = conn.cursor()
            if len(args) > 0:
                self.cursor.execute(smt, args)
            else:
                self.cursor.execute(smt, kwargs)
            return self.cursor
        except Exception:
            self.cursor.close()
            self.cursor = None
            logger.error(f"query failed: {smt}")    
            raise Exception("query failed")

    def query(self, smt: str, *args, **kwargs):
        " query (generic, returns a cursor)"
        return self._query(smt, args, kwargs)

    def release(self):
        if not self.cursor: raise Exception("cursor is already released")
        self.cursor.close()
        self.cursor = None

    def query_scalar(self, smt: str, *args, **kwargs):
        " query a single value "
        cur = self._query(smt, args, kwargs)
        try:
            row = cur.fetchone()
            if row is None: return None
            if len(row) != 1: raise Exception("query returned too many values")
            return row[0]
        finally:
            self.release()

    def query_one(self, smt: str, *args, **kwargs) -> Tuple:
        " query a single row (returns a tuple) "
        cur = self._query(smt, args, kwargs)
        try:
            return cur.fetchone()
        finally:
            self.release()

    def query_one_dict(self, smt: str, *args, **kwargs) -> Dict:
        " query a single row (returns a dictionary) "
        cur = self._query(smt, args, kwargs)
        try:
            row = cur.fetchone()
            result = { cur.description[i][0]: v for i,v in enumerate(row) }
            return result
        finally:
            self.release()

    def query_many(self, smt: str, *args, **kwargs) -> List[Tuple]:
        " query more than one row (returns a list of tuples)"
        cur = self._query(smt, args, kwargs)
        try:
            return cur.fetchall()
        finally:
            self.release()

    def query_many_dict(self, smt: str, *args, **kwargs) -> List[Dict]:
        " query multiple rows (returns a list of dictionarys)"
        cur = self._query(smt, args, kwargs)
        try:
            rows = cur.fetchmany(20)
            if len(rows) == 0: return []

            names = [i[0] for i in cur.description]        

            result = []
            while len(rows) != 0:
                for r in rows:
                    result.append({ names[i]: v for i,v in enumerate(r) })
                rows = cur.fetchmany(20)
            return result
        finally:
            self.release()

    def _load_dtype_map(self):
        recs = self.query_many("""
SELECT oid, typname
from pg_type
where typname in (
    'bool', 
    'int2', 'int4', 'int8', 
    'float4', 'float8',
    'char', 'text', 'varchar',
    'date')
""")

        names_to_dtypes = {
            'bool': np.bool,
            'int2': np.int16,
            'int4': np.int32,
            'int8': np.int64,
            'float4': np.float,
            'float8': np.double,
            'char': np.char,
            'text': np.str,
            'varchar': np.str,
            'date': date
        }

        results = {}
        for oid, typname in recs:
            results[oid] = names_to_dtypes[typname]
        self.dtype_map = results            


    def _make_array(self, nrows: int, descr) -> np.array:
        
        dtype = self.dtype_map.get(descr.type_code)
        if dtype == None:
            raise Exception(f"Column {descr.name} has an unsupported type_code ({descr.type_code}")
        return np.zeros(nrows, dtype=dtype)

    def query_frame(self, smt: str, *args, **kwargs) -> pd.DataFrame:
        " query multiple rows (returns a data frame)"

        if self.dtype_map == None: self._load_dtype_map()

        cur = self._query(smt, args, kwargs)
        try:

            names = [d[0] for d in cur.description]
            ncols = len(names)
            vecs = [self._make_array(cur.rowcount, d) for d in cur.description]

            if cur.rowcount > 0: 
                idx = 0
                rows = cur.fetchmany(100)
                while len(rows) != 0:
                    for r in rows:
                        for i in range(ncols):
                            vecs[i][idx] = r[i]
                        idx += 1
                    rows = cur.fetchmany(100)
            return pd.DataFrame({ n:v for n,v in zip(names, vecs) })
        finally:
            self.release()

# --------------------------------------------------
class DatabaseSchema:

    def __init__(self, db: Database):
        self.db = db

    def does_table_exist(self, table_name: str) -> bool:
        "check if a table exists"

        n = self.db.query_scalar("""
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' and table_name = %s
""", table_name)
        return n != None

    def does_column_exist(self, table_name: str, column_name) -> bool:
        "check if a column exists on a table"
        n = self.db.query_scalar("""
SELECT column_name
FROM information_schema.columns 
WHERE table_schema = 'public' and table_name = %s
  AND column_name = %s
""", table_name, column_name)
        return n != None

    def get_table_schema(self, table_name: str) -> List[Dict]:
        "get the schema of a table (column_name, ordinal_position, data_type, character_maximum_length)"

        t = self.db.query_many("""
SELECT column_name, ordinal_position, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_schema = %t
ORDER BY ordinal_postion
""", t=table_name)
        return t


# ----------------------------------

def config(filename='database.ini', section='postgresql') -> Dict:
    "read the configuration values out of an .ini file"
    parser = ConfigParser()

    for p in [".", "..", "../.."]:
        file_path = os.path.join(p, filename)
        if os.path.exists(file_path):
            parser.read(file_path)
            db = {}
            if parser.has_section(section):
                params = parser.items(section)
                for param in params:
                    db[param[0]] = param[1]
            else:
                raise Exception('Section {0} not found in the {1} file'.format(section, filename))
            return db

    raise Exception("Could not find {0}".format(filename))


def connect_to_db(params: Dict = None) -> Database:
    "get an instance of the Database wrapper"

    if params == None:
        params = config()

    logger.debug("  connect at {0}".format({ x: params[x] for x in params if x != "password"}))
    db =  Database(params)
    db.schema = DatabaseSchema(db)
    return db