"""This file provides all fixtures for the testing scripts."""

import sys

sys.path.insert(1, "..")

import sqlite3

import pytest

from tools.addons.gets import get_to_root


@pytest.fixture
def session():
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
