from loguru import logger
from typing import Dict, List, Tuple
import os
from threading import Lock

import psycopg2
from psycopg2 import pool

from datetime import date, datetime
import pandas as pd
import numpy as np

from shared import configuration

class Database:
    "wrapper around a postgres database connection"

    def __init__(self, pool_or_params):

        self._conn = None
        self._pool = None            

        if type(pool_or_params) == dict: # if not pooled, create an internal connection
            self._conn = psycopg2.connect(**{n: pool_or_params[n] for n in pool_or_params if n != "pooled"})             
        elif type(pool_or_params).__name__ == "DatabaseConnectionPool": # pool case
            self._pool = pool_or_params            
        else:
            raise Exception(f"Invalid parameter type ({type(pool_or_params)}")

        self.schema = None
        self.dtype_map = None

    def close(self):
        if self._conn:
            if self._pool: # if it is a pooled connection, return it to the pool
                self._pool.release(self._conn)
            else: # if not, close it
                self._conn.close()
            self._conn = None


    def execute(self, smt: str, *args, **kwargs) -> None:
        " run a command against the DB"

        if self._pool: # if it is a pooled connection, get it to the pool
            conn = self._pool.acquire()
        else:
            conn = self._conn
        
        try:
            cursor = conn.cursor()
            if len(args) > 0:
                cursor.execute(smt, args)
            elif len(kwargs) > 0:
                cursor.execute(smt, kwargs)
            else:
                cursor.execute(smt)
            conn.commit()
        except Exception:
            logger.error(f"execute failed: {smt}")    
            raise Exception("execute failed")
        finally:
            cursor.close()
            if self._pool:
                self._pool.release(conn)


    def _query(self, smt: str, args: Tuple, kwargs: Dict) -> Tuple:
        " query (generic, returns a (cursor,connection))"

        if self._pool: # if it is a pooled connection, get it to the pool
            conn = self._pool.acquire()
        else:
            conn = self._conn

        # unwrap items if necessary
        if len(args) == 1: 
            if type(args[0]) == dict:
                kwargs = args[0]
                args = () 
            elif type(args[0]) == tuple or type(args[0]) == list:
                args = args[0]

        if len(kwargs) > 0 and len(args) > 0:
            raise Exception("Cannot process both positional and kwarg paramaters in same query")

        try:
            cursor = conn.cursor()
            if len(args) > 0:
                cursor.execute(smt, args)
            else:
                cursor.execute(smt, kwargs)
            return cursor, conn
        except Exception:
            cursor.close()
            if self._pool: # if pooled, return it
                self._pool.release(conn)
            logger.error(f"query failed: {smt}")    
            raise Exception("query failed")

    def begin_query(self, smt: str, *args, **kwargs) -> Tuple:
        "begin a query (generic, returns (cursor, connection))"
        return self._query(smt, args, kwargs)

    def finish_query(self, cursor, conn):
        "finish a query (releases resources)"

        if cursor:
            cursor.close()
        if conn:
            if self._pool:
                self._pool.release(conn)


    def query_scalar(self, smt: str, *args, **kwargs):
        " query a single value "
        
        cur, conn = self._query(smt, args, kwargs)
        try:
            row = cur.fetchone()
            if row is None: return None
            if len(row) != 1: raise Exception("query returned too many values")
            return row[0]
        finally:
            self.finish_query(cur, conn)

    def query_one(self, smt: str, *args, **kwargs) -> Tuple:
        " query a single row (returns a tuple) "
        cur, conn = self._query(smt, args, kwargs)
        try:
            return cur.fetchone()
        finally:
            self.finish_query(cur, conn)

    def query_one_dict(self, smt: str, *args, **kwargs) -> Dict:
        " query a single row (returns a dictionary) "
        cur, conn = self._query(smt, args, kwargs)
        try:
            row = cur.fetchone()
            if row == None: return None
            result = { cur.description[i][0]: v for i,v in enumerate(row) }
            return result
        finally:
            self.finish_query(cur, conn)

    def query_many(self, smt: str, *args, **kwargs) -> List[Tuple]:
        " query more than one row (returns a list of tuples)"
        cur, conn = self._query(smt, args, kwargs)
        try:
            return cur.fetchall()
        finally:
            self.finish_query(cur, conn)

    def query_many_dict(self, smt: str, *args, **kwargs) -> List[Dict]:
        " query multiple rows (returns a list of dictionarys)"
        cur, conn = self._query(smt, args, kwargs)
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
            self.finish_query(cur, conn)

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

        cur, conn = self._query(smt, args, kwargs)
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
            self.finish_query(cur, conn)

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

class DatabaseConnectionPool:
    "a wrapper around a threaded connection pool"
    
    def __init__(self, params: Dict):
        self.params = params
        self._pool = psycopg2.pool.ThreadedConnectionPool(1, 20, **{n: params[n] for n in params if n != "pooled"})

    def check(self, params: Dict):
        "check if params are identical to current pool setting"
        if self.params == None: return
        for k in self.params:
            v1 = self.params[k]
            v2 = params[k]
            if v1 != v2: raise Exception(f"Paramater {k} is different from expected value in pool.")

    def acquire(self):
        "get a connection"
        return self._pool.getconn()

    def release(self, conn):
        "return a connection"        
        self._pool.putconn(conn)

    def shutdown(self):
        "shutdown pool"
        self._pool.closeall()
        self._pool = None

# ----------------------------------
g_connection_pools = {}

def find_pool(params: Dict) -> DatabaseConnectionPool:
    "find a connection pool in a global list"    

    host, db, user = params["host"], params["database"], params["user"]
    key = f"{host}|{db}|{user}"

    xpool = g_connection_pools.get(key)

    # protect against multiple threads changing collection
    lock = Lock()
    lock.acquire()
    try:
        if xpool == None:
            xpool = DatabaseConnectionPool(params)
            g_connection_pools[key] = xpool
        else:
            xpool.check(params)
        return xpool
    finally:
        lock.release()

# ----------------------------------
def connect_to_db(params: Dict = None) -> Database:
    "get an instance of the Database wrapper"

    if params == None:
        params = configuration.read_db_settings()

    use_pool = params["pooled"]

    logger.debug("  connect at {0}".format({ x: params[x] for x in params if x != "password"}))
    if use_pool:
        pool = find_pool(params)
        db =  Database(pool)
    else:
        db =  Database(params)

    db.schema = DatabaseSchema(db)
    return db