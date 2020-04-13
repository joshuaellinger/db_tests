import base64
import os
from loguru import logger
from cryptography.fernet import Fernet
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

def password_to_key(password: str, salted=False) -> bytes:
    "convert a password to a key"

    bpassword = password.encode()
    salt = os.urandom(16) if salted else b''
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=10000,
        backend=default_backend()
    )
    key = base64.urlsafe_b64encode(kdf.derive(bpassword))
    return key

def encrypt(password: str, msg: str) -> str:
    "encrypt a message"
    key = password_to_key(password)
    f = Fernet(key)
    token = f.encrypt(msg.encode())

    encrypted_msg = base64.urlsafe_b64encode(token).decode()
    return encrypted_msg

def decrypt(password: str, encrypted_msg: str) -> str:
    "decrypt a message"
    key = password_to_key(password)
    token = base64.urlsafe_b64decode(encrypted_msg.encode())
    f = Fernet(key)
    msg = f.decrypt(token).decode()
    return msg

def encrypt_keyed(password: str, msg: str) -> [str, str]:
    "encrypt a message, returns message and salted key"
    key = password_to_key(password, salted=True)
    f = Fernet(key)
    token = f.encrypt(msg.encode())

    encrypted_msg = base64.urlsafe_b64encode(token).decode()
    return encrypted_msg, key.decode()

def decrypt_keyed(key: str, encrypted_msg: str) -> str:
    "decrypt a message, requires the salted key rather than the password"
    token = base64.urlsafe_b64decode(encrypted_msg.encode())
    f = Fernet(key.encode())
    msg = f.decrypt(token).decode()
    return msg


