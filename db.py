import json
import pymysql
from pathlib import Path


def load_config(config_path=None):
    if config_path is None:
        config_path = Path(__file__).parent / "config.json"
    with open(config_path, encoding="utf-8") as f:
        return json.load(f)


def get_connection(config=None):
    if config is None:
        config = load_config()
    db = config["db"]
    return pymysql.connect(
        host=db["host"],
        port=db["port"],
        user=db["user"],
        password=db["password"],
        database=db["database"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )
