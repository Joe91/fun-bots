import os
import sys

from deep_translator import GoogleTranslator

os.chdir(os.getcwd() + "/..")

with open("DEFAULT.lua", "r") as template:
    file = template.readlines()


def main() -> None:

    LANG = sys.argv[1]

    translator = GoogleTranslator(source="en", target=LANG)

    def translate(line: str) -> str:
        splitted_line = line.split('"')
        splitted_line.remove("")
        splitted_line.insert(3, translator.translate(splitted_line[1]))
        return '"'.join(splitted_line)

    file[0] = file[0].replace("'xx_XX'", f"'{LANG}_{LANG.upper()}'")

    for index, line in enumerate(file):
        if line.startswith("Language:add"):
            file[index] = translate(line)

    with open(f"{LANG}_{LANG.upper()}.lua", "w", encoding="utf-8") as translated_file:
        translated_file.writelines(file)


if __name__ == "__main__":
    main()
