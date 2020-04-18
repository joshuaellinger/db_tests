#
#

from abc import abstractclassmethod, ABC
from typing import List, Dict
from loguru import logger
import pandas as pd
import numpy as np
import re
import socket

from shared.util import state_abbrevs
from shared import udatetime

from data.worksheet_wrapper import WorksheetWrapper

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
KEY_PATH = "credentials-scanner.json"

class TabBase(ABC):

    def __init__(self):
        self._df: pd.DataFrame = None

    @property
    def df(self) -> pd.DataFrame:
        return self._df

    def load(self) -> pd.DataFrame:
        try:
            self._df = self._load_implementation()
            return self._df
        except socket.timeout:
            logger.error(f"Could not fetch working")
            return None
        except Exception as ex:
            logger.exception(ex)                
            logger.error(f"Could not load working", exception=ex)
            return None

    @abstractclassmethod
    def _load_implementation(self) -> bool:
        pass

    def convert_to_int(self, df: pd.DataFrame, col_name: str) -> pd.Series:
        """ convert a series to int even if it contains bad data 
            blanks -> -1000
            errors -> -1001
        """

        # clean up the values (remove commas, fractions, whitespace)
        s = df[col_name].str.strip().replace(",", "").replace("\\.[0-9][0-9]?$", "", regex=True)
        df[col_name] = s

        # set blanks to -1000
        is_blank = (s == "")
        df.loc[is_blank, col_name] = "-1000"

        # find anything that is bad, trace, set it to -1001
        s = df[col_name]
        is_bad = (~s.str.isnumeric() & ~is_blank)

        df_errs = df[is_bad][["state", col_name]]
        if df_errs.shape[0] != 0: 
            logger.error(f"invalid input values for {col_name}:\n{df_errs}")
            for _, e_row in df_errs.iterrows():
                v = e_row[col_name]
                logger.error(f"Invalid {col_name} value ({v}) for {e_row.state}")

            s = s.where(is_bad, other="-1001")
            df[col_name] = s

        # conver to int
        df[col_name] = df[col_name].astype(np.int)

    def convert_to_date(self, df: pd.DataFrame, name: str, as_eastern: bool):

        def standardize_date(d: str) -> str:
            sd, err_num = udatetime.standardize_date(d)
            return str(err_num) + sd

        s = df[name]
        s_date = s.apply(standardize_date)

        s_idx = s_date.str[0].astype(np.int)
        names = ["", "changed", "blank", "missing date", "missing time", "bad date", "bad time"]
        s_msg = s_idx.map(lambda x: names[x])

        s_date = s_date.str[1:]

        s_date = pd.to_datetime(s_date, format="%m/%d/%Y %H:%M")
        if as_eastern:
            s_date = s_date.apply(udatetime.pandas_timestamp_as_eastern)

        df[name] = s_date
        df[name + "_msg"] = s_msg


    def cleanup_names(self, df:pd.DataFrame):
        " remove extra whitespace column names "
        cols = []
        for n in df.columns:            
            #n1 = n.replace("\r", "").replace("\n", " ")
            n1 = re.sub(r"\s+", " ", n)
            n1 = n1.strip()
            cols.append(n1)
        df.columns = cols

    def remap_names(self, df: pd.DataFrame, column_map: Dict):
        has_error = False
        names = []
        to_delete = []
        for n in df.columns.values:
            n2 = column_map.get(n)
            if n2 == None:
                has_error = True
                logger.error(f"  Unexpected column: [{n}] in google sheet")
            elif n2 == '':
                to_delete.append(n)
            else:
                names.append(n2)
        for n in column_map:
            if not (n in df.columns):
                has_error = True
                logger.error(f"  Missing column: [{n}] in google sheet")

        if has_error:
            raise Exception("Columns in google have changed")

        for n in to_delete:
            del df[n]

        df.columns = names

