from tools.addons.gets import get_it_running, get_tables
from tools.addons.sets import set_permission_config_files


def export_permission_and_config() -> None:

    connection, cursor = get_tables()
    set_permission_config_files(cursor)
    connection.close()


if __name__ == "__main__":
    get_it_running(export_permission_and_config)
