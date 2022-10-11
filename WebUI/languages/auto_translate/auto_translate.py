import sys
import os
from deep_translator import GoogleTranslator

os.chdir(os.getcwd() + "/..")

with open("DEFAULT.js", "r") as template:
    file = template.readlines()


def main() -> None:

    LANG = sys.argv[1]

    def translate(line: str) -> str:
        splitted_line = line.split('"')
        splitted_line.remove("")
        splitted_line.insert(
            3, GoogleTranslator(source="en", target=LANG).translate(splitted_line[1])
        )
        return '"'.join(splitted_line)

    langs_dict = GoogleTranslator().get_supported_languages(as_dict=True)
    file[0] = file[0].replace("'xx_XX'", f"'{LANG}_{LANG.upper()}'")
    file[2] = file[2].replace("English", [k for k, v in langs_dict.items() if v == LANG][0].capitalize())
    file[3] = file[3].replace("Unknown", "GoogleTranslator")

    for index, line in enumerate(file):
        if index > 5 and line.startswith("\t\"") and not line.split(":")[0].startswith("\t\"\""):
            file[index] = translate(line)

    with open(f"{LANG}_{LANG.upper()}.js", "w", encoding="utf-8") as translated_file:
        translated_file.writelines(file)


if __name__ == "__main__":
    main()
