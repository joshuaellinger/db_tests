from typing import Dict
import os
from configparser import ConfigParser

from shared import encryption

# -----------------------------------
# encryption support
def _get_preshared_key():
    key = os.environ.get("CONFIG_PRESHARED_KEY")
    if key == None or key == "": 
        raise Exception("Missing env variable CONFIG_PRESHARED_KEY for encrypting configuration values")
    return key

def _is_encrypted(msg: str) -> bool:
    if msg == None: return True
    return msg.startswith("ENCRYPTED:")

def _decrypt_value(val: str) -> str:
    pwd = _get_preshared_key()

    if not val.startswith("ENCRYPTED:"): raise Exception("Value is not encrypted")
    val = val[len("ENCRYPTED:"):]
    val = encryption.decrypt(pwd, val)
    return val

def _encrypt_on_disk(file_path: str, parser: ConfigParser, section: str, name: str): 
    pwd = _get_preshared_key()

    val = parser.get(section, name)
    val = encryption.encrypt(pwd, val)
    val = "ENCRYPTED:" + val 
    parser.set(section, name, val)
    
    tmp = file_path + ".tmp"
    with open(file_path + ".tmp", "w") as f:
        parser.write(f)

    if os.path.exists(file_path): os.remove(file_path)
    os.rename(tmp, file_path)

# -----------------------------------

class Configuration():
    """Configuration manages getting values out of a .ini file.

    It adds three things over the raw ConfigParser:

    1. It searchs for both a standard (.ini) and a local version (.local.ini)
    version.  Use .local.ini to override values on a local instance.

    2. It loads a section into a dictionary.  Pass in a dictionary containing 
    instructions and it will validate that you have the required fields and 
    no extra fields.

    3. It can encrypt values using a pre-shared key. Set an env variable (CONFIG_PRESHARED_KEY)
    and instruct it to a variable should 'encrypyted'.  The value will be encrypted on first
    read.

    See load_section for configuration syntax
    """

    def __init__(self, file_name: str == None):
        self.file_path = None
        self.parser = None

        if file_name:
            file_path = self.find_config_path(file_name)
            self.load(file_path)

    def load(self, file_path: str):
        "load configuration from an absolute path"        
        self.file_path = file_path
        self.parser = ConfigParser()
        self.parser.read(file_path)

    def find_config_path(self, filename: str) -> str:
        "find the path to a config in current/parent directories"
        alt_filename = filename.replace(".ini", ".local.ini")
        for p in [".", "..", "../..", "../../.."]:

            file_path = os.path.join(p, alt_filename)
            if os.path.exists(file_path): return file_path

            file_path = os.path.join(p, filename)
            if os.path.exists(file_path): return file_path

        raise Exception("Could not find {0}".format(filename))

    def load_section(self, section: str, validation: Dict = None) -> Dict:
        """load a section from a config file into a Dict with validation

        validation may look like this {
            "option1": "required",
            "option2": "optional",
            "option3": "required,encrypted",
            "option4": "optional,encrypted"
        }
        """

        items = {}
        if self.parser.has_section(section):
            params = self.parser.items(section)
            for param in params:
                items[param[0]] = param[1]
        else:
            raise Exception('Section {0} not found in the {1} file'.format(section, self.file_path))

        if validation != None:
            self._apply_validation(items, section, validation)
        return items

    def _apply_validation(self, items: Dict, section: str, config: Dict):
        """apply validation rules
        """
        for n in items:
            flags = config.get(n)
            if flags == None:
                raise Exception('Section {0} has an unexpected name {1}'.format(section, n))

            if "encrypted" in flags:
                if _is_encrypted(items[n]):
                    items[n] = _decrypt_value(items[n])
                else:
                    _encrypt_on_disk(self.file_path, self.parser, section, n)

        for n in config:
            flags = config[n]
            if "required" in flags:
                if not (n in items):
                    raise Exception('Section {0} is missing a required name {1}'.format(section, n))


# -------------------------

def read_db_settings(file_name='database.ini', section='postgresql') -> Dict:
    "read the database setting out of an .ini file"

    config = Configuration(file_name)
    db = config.load_section(section, validation={
        "host": "required",
        "database": "required",
        "user": "required",
        "password": "required,encrypted",
        "connect_timeout": "optional",
        "pooled": "optional",
    })
    return db