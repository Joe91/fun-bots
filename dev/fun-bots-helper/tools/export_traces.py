from addons.gets import get_all_tables, get_it_running, get_to_root
from addons.sets import set_traces_files


def export_traces() -> None:
    get_to_root()
    connection, cursor = get_all_tables()
    set_traces_files(cursor)
    connection.close()


if __name__ == "__main__":
    get_it_running(export_traces)
