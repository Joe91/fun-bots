"""This file provides all fixtures for the testing scripts."""

import sys

sys.path.append("../")

import sqlite3
from typing import Generator

import pytest

from src.tools.addons.gets import get_to_root


@pytest.fixture
def session() -> Generator:
    """Yield a cursor of a temporary mod.db copy.

    Args:
        None

    Returns:
        None
    """
    get_to_root()
    connection = sqlite3.connect("mod.db")
    temp_connection = sqlite3.connect(":memory:")
    connection.backup(temp_connection)
    db_session = temp_connection.cursor()
    yield db_session
    connection.close()
    temp_connection.close()
