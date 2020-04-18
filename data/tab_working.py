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

from shared.util import state_abbrevs
from shared import udatetime

from data.worksheet_wrapper import WorksheetWrapper

from data.tab_base import TabBase


def get_column_map() -> Dict:
    return {
        'State':'state',

        'Dashboard': '',
        'State Name': '',
        'State COVID-19 Page': '',
        'State Social Media': '',
        'Press Conferences': '',
        'GIS Query': '',
        'Other': '',
        '#Reporting': '',
        'URL Watch': '',
        'Status': '',
        'URL Watch Diff': '',
        'Alerted': '',
        'Last Alert': '',
        'Error': '',
        'Prev Last Check (ET)': '',
        'Freshness': '',
        'Flagged': '',
        'Time zone +/–': '',
        'Public': '',
        '': '',
    #    'Private': '',

        'Local Time':'localTime',
        'Positive':'positive',
        'Negative':'negative',
        'Pending':'pending',
        'Currently Hospitalized':'hospitalized',
        'Cumulative Hospitalized':'hospitalizedCumulative',
        'Currently in ICU':'inIcu',
        'Cumulative in ICU':'inIcuCumulative',
        'Currently on Ventilator':'onVentilator',
        'Cumulative on Ventilator':'onVentilatorCumulative',
        'Recovered':'recovered',
        'Deaths':'death',
        'Total':'total',
        'Last Update (ET)': 'lastUpdateEt',
        'Last Check (ET)': 'lastCheckEt',
        'Checker':'checker',
        'Doublechecker':'doubleChecker'
    }


class TabWorking(TabBase):

    def __init__(self):
        super(TabWorking, self).__init__()

        # worksheet dates
        self.last_publish_time = ""
        self.last_push_time = ""
        self.current_time = ""

    def parse_dates(self, dates: List):
        if len(dates) != 5:
            raise Exception("First row layout (containing dates) changed")
        last_publish_label, last_publish_value, last_push_label, \
            last_push_value, current_time_field = dates

        if last_publish_label != "Last Publish Time:":
            raise Exception("Last Publish Time (cells V1:U1) moved")
        if last_push_label != "Last Push Time:":
            raise Exception("Last Push Time (cells Z1:AA1) moved")
        if not current_time_field.startswith("CURRENT TIME: "):
            raise Exception("CURRENT TIME (cell AG1) moved")

        self.last_publish_time = last_publish_value
        self.last_push_time = last_push_value
        self.current_time = current_time_field[current_time_field.index(":")+1:].strip()


    def _load_implementation(self) -> pd.DataFrame:
        """Load the working (unpublished) data from google sheets"""

        gs = WorksheetWrapper()
        dev_id = gs.get_sheet_id_by_name("dev")

        dates = gs.read_as_list(dev_id, "Worksheet 2!V1:AJ1", ignore_blank_cells=True, single_row=True)
        self.parse_dates(dates)

        df = gs.read_as_frame(dev_id, "Worksheet 2!A2:AL60", header_rows=1)
        self.cleanup_names(df)

        column_map = get_column_map()
        self.remap_names(df, column_map)

        idx = df.columns.get_loc("localTime")
        eidx = df.columns.get_loc("lastUpdateEt")
        for c in df.columns[idx+1:eidx]:
            self.convert_to_int(df, c)

        self.convert_to_date(df, "localTime", as_eastern=False)
        self.convert_to_date(df, "lastUpdateEt", as_eastern=True)
        self.convert_to_date(df, "lastCheckEt", as_eastern=True)

        df = df[ df.state != ""]
        return df


# ------------------------------------------------------------

# --- simple tests
def main():

    tab = TabWorking()
    tab.load()
    logger.info(f"working\n{tab.df.info()}")


if __name__ == '__main__':
    main()
