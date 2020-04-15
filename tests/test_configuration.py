import pytest
from loguru import logger
from shared.configuration import Configuration, read_db_settings 
import os

@pytest.fixture
def ini():

    with open("temp.ini", "w") as f:
        f.write("""
[MySettings]
option1: abc
option2: xyz
""")

    yield "temp.ini"

    os.remove("temp.ini")

@pytest.fixture
def local_ini():

    with open("temp2.ini", "w") as f:
        f.write("""
[MySettings]
option1: abc
option2: xyz
""")

    with open("temp2.local.ini", "w") as f:
        f.write("""
[MySettings]
option1: abc_l
option2: xyz_l
""")

    yield "temp2.ini"

    os.remove("temp2.ini")
    os.remove("temp2.local.ini")

@pytest.fixture
def parent_ini():

    with open("../temp3.ini", "w") as f:
        f.write("""
[MySettings]
option1: abc_p
option2: xyz_p
""")

    yield "../temp3.ini"

    os.remove("../temp3.ini")

def test_basic(ini):

    c = Configuration(ini)
    d = c.load_section("MySettings")
    assert(len(d) == 2)
    assert(d["option1"] == "abc")    
    assert(d["option2"] == "xyz")

def test_search(local_ini, parent_ini):

    c = Configuration(local_ini)
    d = c.load_section("MySettings")
    assert(len(d) == 2)
    assert(d["option1"] == "abc_l")    
    assert(d["option2"] == "xyz_l")

    c = Configuration(parent_ini)
    d = c.load_section("MySettings")
    assert(len(d) == 2)
    assert(d["option1"] == "abc_p")    
    assert(d["option2"] == "xyz_p")

def test_validation(ini):

    c = Configuration(ini)
    d = c.load_section("MySettings", validation= {
        "option1": "required",
        "option2": "optional",
        "option3": "optional"
    })

def test_encryption(ini):

    c = Configuration(ini)
    d = c.load_section("MySettings", validation= {
        "option1": "required",
        "option2": "encrypted"
    })
    assert(len(d) == 2)
    assert(d["option1"] == "abc")    
    assert(d["option2"] == "xyz")

    d = c.load_section("MySettings")
    assert(len(d) == 2)
    assert(d["option1"] == "abc")    
    assert(d["option2"].startswith("ENCRYPTED:"))

    d = c.load_section("MySettings", validation= {
        "option1": "required",
        "option2": "encrypted"
    })
    assert(len(d) == 2)
    assert(d["option1"] == "abc")    
    assert(d["option2"] == "xyz")
