from tools.addons.gets import get_it_running, get_tables
from tools.addons.sets import set_traces_files


def export_traces() -> None:

    connection, cursor = get_tables()
    set_traces_files(cursor)
    connection.close()


if __name__ == "__main__":
    get_it_running(export_traces)
