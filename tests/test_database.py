import pytest
from loguru import logger
from shared.database import connect_to_db, config, Database 

from psycopg2 import OperationalError

@pytest.fixture
def db():
    db = connect_to_db()
    if db.schema.does_table_exist("test_table"):
        db.execute("DROP TABLE test_table")

    yield connect_to_db()

    #if db.schema.does_table_exist("test_table"):
    #    db.execute("DROP TABLE test_table")

def test_connection():
    c = config()
    c["pooled"] = False
    db = connect_to_db(c)
    db.close()


@pytest.mark.slow
def test_bad_connection():

    with pytest.raises(TypeError) as excinfo:
        connect_to_db({})

    c = config()
    c["pooled"] = False
    c["host"] = "xxxx"
    with pytest.raises(OperationalError) as excinfo:
        connect_to_db(c)
    assert(str(excinfo.value) == 'could not translate host name "xxxx" to address: Unknown host\n')

    c = config()
    c["pooled"] = False
    c["host"] = "covidtracking.com"
    c["connect_timeout"] = 1
    with pytest.raises(OperationalError) as excinfo:
        connect_to_db(c)
    assert(str(excinfo.value) == 'timeout expired\n')

    c = config()
    c["pooled"] = False
    c["user"] = "xxxx"
    with pytest.raises(OperationalError) as excinfo:
        connect_to_db(c)
    assert(str(excinfo.value) == 'FATAL:  password authentication failed for user "xxxx"\n')

    c = config()
    c["pooled"] = False
    c["password"] = "xxxx"
    with pytest.raises(OperationalError) as excinfo:
        connect_to_db(c)
    assert(str(excinfo.value) == 'FATAL:  password authentication failed for user "covid"\n')

    c = config()
    c["pooled"] = False
    c["database"] = "xxxx"
    with pytest.raises(OperationalError) as excinfo:
        connect_to_db(c)
    assert(str(excinfo.value) == 'FATAL:  database "xxxx" does not exist\n')


def test_schema(db):

    assert(not db.schema.does_table_exist("test_table"))

    db.execute("""
CREATE TABLE test_table
(
    col varchar(2)
)
""")

    assert(db.schema.does_table_exist("test_table"))
    assert(db.schema.does_column_exist("test_table", "col"))
    assert(not db.schema.does_column_exist("test_table", "x"))

def test_concurrent_queries(db):

    if db.schema.does_table_exist("test_table"):
        db.execute("DROP TABLE test_table")

    db.execute("""
CREATE TABLE test_table
(
    state varchar(2),
    positive int
)
""")

    db.execute("INSERT INTO test_table (state, positive) VALUES ('AL', 1000)")
    db.execute("INSERT INTO test_table (state, positive) VALUES ('TX', 1001)")

    for i in range(10):
        db2 = connect_to_db()
        n = db2.query_scalar("SELECT positive FROM test_table WHERE state = 'AL'")
        assert(n == 1000)

def test_query_variants(db):

    db.execute("""
CREATE TABLE test_table
(
    state varchar(2),
    positive int
)
""")

    db.execute("INSERT INTO test_table (state, positive) VALUES ('AL',1000)")
    db.execute("INSERT INTO test_table (state, positive) VALUES ('TX',1001)")

    n = db.query_scalar("SELECT positive FROM test_table WHERE state = 'AL'")
    assert(n == 1000)
    s = db.query_scalar("SELECT state from test_table where positive = 1001")
    assert(s == "TX")  

    row = db.query_one("SELECT positive FROM test_table WHERE state = 'AL'")
    assert(len(row) == 1 and row[0] == 1000)

    row = db.query_one("SELECT positive FROM test_table WHERE state = 'XX'")
    assert(row is None)

    rows = db.query_many("SELECT * FROM test_table ORDER BY state")
    assert(len(rows) == 2 and rows[0][1] == 1000 and rows[1][1] == 1001)

    rows = db.query_many("SELECT * FROM test_table WHERE positive = 0")
    assert(len(rows) == 0)

    rows = db.query_many_dict("SELECT * FROM test_table ORDER BY state")
    assert(len(rows) == 2 and rows[0]["positive"] == 1000 and rows[1]["positive"] == 1001)

    rows = db.query_many_dict("SELECT * FROM test_table where positive = 0")
    assert(len(rows) == 0)

    df = db.query_frame("SELECT * FROM test_table ORDER BY state")
    assert(df.shape[0] == 2 and df.positive[0] == 1000 and df.positive[1] == 1001)

    df = db.query_frame("SELECT * FROM test_table where positive = 0")
    assert(df.shape[0] == 0)


def test_parametization(db):

    db.execute("""
CREATE TABLE test_table
(
    state varchar(2),
    positive int
)
""")

    db.execute("INSERT INTO test_table (state, positive) VALUES %s", ('AL', 1000))
    db.execute("INSERT INTO test_table (state, positive) VALUES (%s,%s)", 'TX', 1001)

    n = db.query_scalar("SELECT positive FROM test_table WHERE state = 'AL'")

    n2 = db.query_scalar("SELECT positive FROM test_table WHERE state = %s", "AL")
    assert(n == n2)
    n2 = db.query_scalar("SELECT positive FROM test_table WHERE state = %(state)s", state="AL")
    assert(n == n2)    

    n2 = db.query_scalar("SELECT positive FROM test_table WHERE state = %s", ("AL"))
    assert(n == n2)
    n2 = db.query_scalar("SELECT positive FROM test_table WHERE state = %(state)s", {"state":"AL"})
    assert(n == n2)    


