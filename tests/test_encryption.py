import pytest
from loguru import logger
from shared import encryption


def test_round_trip():

    pwd = "pwd123"
    msg = "Hello World"

    logger.info(f"message = {msg}")
    encrypted_msg = encryption.encrypt(pwd, msg)
    logger.info(f"encrypted message = {encrypted_msg}")

    msg2 = encryption.decrypt(pwd, encrypted_msg)
    logger.info(f"result = {msg}")

    assert(msg == msg2)

    encrypted_msg, key = encryption.encrypt_keyed(pwd, msg)
    logger.info(f"encrypted message = {encrypted_msg}")
    logger.info(f"message key = {key}")


    msg2 = encryption.decrypt_keyed(key, encrypted_msg)
    logger.info(f"result = {msg}")

    assert(msg == msg2)
