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

def access_encrypted_file(password: str, path: str) -> str:
    "decrypt a file for use, returns the path to the contents"

    encrypted_path = path + ".encrypted"
    temp_path = path + ".tmp"
    if os.path.exists(temp_path): os.remove(temp_path)

    if os.path.exists(path):
        # if the file exists, save an encrypted copy and move it to the temp name.
        with open(path, "r") as f:
            contents = f.read()
        encrypted_contents = encrypt(password, contents)
        with open(encrypted_path, "w") as f:
            f.write(encrypted_contents)
        os.rename(path, temp_path)        
    elif os.path.exists(encrypted_path):
        # otherwise, decrypt the encrypted copy into the temp name
        with open(encrypted_path, "r") as f:
            encrypted_contents = f.read()
        contents = decrypt(password, encrypted_contents)
        with open(temp_path, "w") as f:
            f.write(contents)
    else:
        raise Exception(f"Missing both plain and encrypted version of {path}")

    return temp_path


def cleanup_encrypted_file(path: str):
    "delete the temp version of the file"

    if path.endswith(".tmp"):
        temp_path = path
    else:
        temp_path = path + ".tmp"
    if os.path.exists(temp_path): 
        os.remove(temp_path)


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


