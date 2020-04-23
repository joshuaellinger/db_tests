import os
from loguru import logger
import re
from shared.database import connect_to_db

import hashlib

class DatabaseOperations:
    " perform database maintainence operations "

    def __init__(self, option: str):

        if not option in ["option-a", "option-b", "option-c"]:
            raise Exception(f"Invalid option {option}")

        self.base_dir = "."
        self.db = connect_to_db(option)
        self.schema_dir = "schema_" + option.replace("-", "_")

    def _load_file(self, file_name: str):
        file_path = os.path.join(self.base_dir, self.schema_dir, file_name)
        if not os.path.exists(file_path): 
            raise Exception(f"File {file_path} does not exist")
        
        with open(file_path, "r") as f:
            return f.read()

    def init_schema(self):
        content = self._load_file("init.sql")
        self.db.execute(content)

    def drop_all(self):
        content = self._load_file("drop.sql")
        self.db.execute(content)

    def _process_one_upgrade(self, fn: str) -> bool:
            
        content = self._load_file(fn)
        check_sum = hashlib.md5(content.encode()).hexdigest()

        m = re.match(r"upgrade_(20[0-9]{6})_([0-9]{2})\.sql", fn)
        xid = int(m[1] + m[2])
        
        rec = self.db.query_one_dict("select * from schema_info where schema_info_id = %s", xid)
        if rec != None:
            label = rec["label"]
            dt = rec["applied_at"]
            logger.info(f"  file {fn} already applied - {label}")
            if check_sum != rec["content_checksum"]:
                logger.error(f"  file {fn} content changed since being applied at {dt}")
                return False
        elif not content.startswith("--"):
            logger.error(f"  file {fn} does not start with a comment line (used as label)")
            return False
        else:

            idx = content.index("\n")
            label = re.sub(r"-+", "", content[0:idx]).strip()

            logger.info(f"  file {fn} apply - {label}")
            self.db.execute(content)

            self.db.execute(f"insert into schema_info (schema_info_id, applied_at, label, content_checksum) values (%s, now(), %s, %s)",
                xid, label, check_sum)
            return True

    def upgrade_schema(self):

        if not self.db.schema.does_table_exist("schema_info"):
            raise Exception("Init DB before calling upgrade")

        upgrade_files = []
        for fn in os.listdir(os.path.join(self.base_dir, self.schema_dir)):
            if not re.match(r"upgrade_.*\.sql", fn): continue
            m = re.match(r"upgrade_(20[0-9]{6})_([0-9]{2})\.sql", fn)
            if m is None: 
                logger.error(f"Invalid upgrade file ({fn}), must be named upgrade_YYYYMMDD_NN.sql")
                return
            upgrade_files.append(fn)

        if len(upgrade_files) == 0:
            logger.info("no upgrade files found")
            return

        upgrade_files.sort()

        failed = False
        for fn in upgrade_files:
            if failed:
                logger.warning(f"  skip {fn} due to previous error")
            elif not self._process_one_upgrade(fn):
                failed = True

    def load_sample(self):
        content = self._load_file("sample_data.sql")
        self.db.execute(content)


    def load_checks(self):
        raise Exception("Load Checks not implemented")