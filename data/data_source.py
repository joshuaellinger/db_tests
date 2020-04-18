#
#
from typing import List, Dict
from loguru import logger
import pandas as pd
import socket

from data.tab_working import TabWorking
from data.tab_checks import TabChecks

class DataSource:

    def __init__(self):
        self._working: TabWorking = None
        self._checks: TabChecks = None


    @property
    def working(self) -> pd.DataFrame:
        " the working tab from the google sheet"

        df = self._working.df
        if df is None:
            df = self._working.load()
        return df

    @property
    def checks(self) -> pd.DataFrame:
        " the checks tab from the google sheet"

        df = self._checks.df
        if df is None:
            df = self._checks.load()
        return df

# ------------------------------------------------------------

# --- simple tests
def main():

    ds = DataSource()
    logger.info(f"working\n{ds.working.info()}")
    logger.info(f"checks\n{ds.checks.info()}")


if __name__ == '__main__':
    main()
