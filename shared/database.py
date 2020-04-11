from loguru import logger
from typing import Dict
from configparser import ConfigParser
import os
import psycopg2

def config(filename='database.ini', section='postgresql') -> Dict:

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

def connect_to_db():

    params = config()

    logger.info("  connect at {0}".format({ x: params[x] for x in params if x != "password"}))

    conn = psycopg2.connect(**params)
    return conn
