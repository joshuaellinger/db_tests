#

from typing import List, Dict
from loguru import logger
import pandas as pd
from urllib.request import urlopen
import json
import numpy as np
import re
import requests
import socket
import io

from datetime import datetime
from shared.util import state_abbrevs
from shared import udatetime

from data.worksheet_wrapper import WorksheetWrapper

from data.tab_base import TabBase

def get_column_map() -> Dict:
    return {
        'State':'state',

        'Positive':'positive',
        'Negative':'negative',
        'Pending':'pending',
        'Hospitalized – Currently':'hospitalized',
        'Hospitalized – Cumulative':'hospitalizedCumulative',
        'In ICU – Currently':'inIcu',
        'In ICU – Cumulative':'inIcuCumulative',
        'On Ventilator – Currently':'onVentilator',
        'On Ventilator – Cumulative':'onVentilatorCumulative',
        'Recovered':'recovered',
        'Death':'death',
        'Total':'total',
        'Last update (ET)': 'lastUpdateEt',
        'Check time (ET)': 'lastCheckEt',
        'Checker':'checker',
        'Double checker':'doubleChecker',
        'Comments':'comments',
        'pushDate':'pushDate'
    }

def get_column_types() -> Dict:
    return {
        'state':str,

        'positive':int,
        'negative':int,
        'pending':int,
        'hospitalized':int,
        'hospitalizedCumulative':int,
        'inIcu':int,
        'inIcuCumulative':int,
        'onVentilator':int,
        'onVentilatorCumulative':int,
        'recovered':int,
        'death':int,
        'total':int,
        'lastUpdateEt':datetime,
        'lastCheckEt':datetime,
        'checker':str,
        'doubleChecker':str,
        'comments':str,
        'pushDate':datetime
    }


class TabChecks(TabBase):

    def __init__(self):
        super(TabChecks, self).__init__()

    def _load_implementation(self) -> pd.DataFrame:
        """Load the checks data from google sheet"""

        gs = WorksheetWrapper()
        dev_id = gs.get_sheet_id_by_name("dev")

        props = gs.get_grid_properties(dev_id, "Checks")
        nrows = props["rowCount"]

        df = gs.read_as_frame(dev_id, "Checks!A2:S" + str(nrows), header_rows=1)
        self.cleanup_names(df)


        column_map = get_column_map()
        self.remap_names(df, column_map)

        # special case fixes:
        logger.info("special cases:")
        is_bad_pending = df["pending"].str.startswith("-")
        logger.info(f"  # rows with pending < 0: {is_bad_pending.shape[0]:,}")
        df.loc[is_bad_pending, "pending"] = "0"

        column_types = get_column_types()
        for c in column_types:
            if column_types[c] == int:
                logger.info(f"convert {c} to int")
                self.convert_to_int(df, c)
            elif column_types[c] == datetime:
                logger.info(f"convert {c} to datetime")
                self.convert_to_date(df, c, as_eastern=True)

        df = df[ df.state != ""]
        return df


# ------------------------------------------------------------

# --- simple tests
def main():

    tab = TabChecks()
    tab.load()
    logger.info(f"checks\n{tab.df.info()}")
    tab.df.to_csv("checks.csv", sep=",")    
    logger.info("done")



if __name__ == '__main__':
    main()
