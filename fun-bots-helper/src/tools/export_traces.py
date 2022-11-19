from tools.addons.gets import get_all_tables, get_it_running
from tools.addons.sets import set_traces_files


def export_traces() -> None:

    connection, cursor = get_all_tables()
    set_traces_files(cursor)
    connection.close()


if __name__ == "__main__":
    get_it_running(export_traces)
