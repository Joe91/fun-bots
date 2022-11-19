from tools.addons.gets import get_all_tables, get_it_running
from tools.addons.sets import set_permission_config_files


def export_permission_and_config() -> None:

    connection, cursor = get_all_tables()
    set_permission_config_files(cursor)
    connection.close()


if __name__ == "__main__":
    get_it_running(export_permission_and_config)
