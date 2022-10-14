import os


def go_back_to_root() -> None:
    cwd_splitted = os.getcwd().split("/")
    new_cwd = "/".join(cwd_splitted[: cwd_splitted.index("fun-bots") + 1])
    os.chdir(new_cwd)
