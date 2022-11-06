import sys

from addons.gets import get_to_root, get_translation
from deep_translator import GoogleTranslator


def create_language(lang: str) -> None:
    get_to_root()
    translator = GoogleTranslator(source="en", target=lang)
    langs_dict = GoogleTranslator().get_supported_languages(as_dict=True)
    lang_name = [k for k, v in langs_dict.items() if v == lang][0].capitalize()

    lua_path = "ext/Shared/Languages"

    with open(lua_path + "/DEFAULT.lua", "r") as template:
        file = template.readlines()

    file[0] = file[0].replace("'xx_XX'", f"'{lang}_{lang.upper()}'")

    print(f"\nTranslating DEFAULT.lua to {lang_name}...")

    for index, line in enumerate(file):
        if line.startswith("Language:add"):
            file[index] = get_translation(translator, line)

    with open(
        lua_path + f"/{lang}_{lang.upper()}.lua", "w", encoding="utf-8"
    ) as translated_file:
        translated_file.writelines(file)

    print(f"\n{lang}_{lang.upper()}.lua Created")

    js_path = "WebUI/languages"

    with open(js_path + "/DEFAULT.js", "r") as template:
        file = template.readlines()

    file[0] = file[0].replace("'xx_XX'", f"'{lang}_{lang.upper()}'")
    file[2] = file[2].replace("English", lang_name)
    file[3] = file[3].replace("Unknown", "GoogleTranslator")

    print(f"\nTranslating DEFAULT.js to {lang_name}...")

    for index, line in enumerate(file):
        if (
            index > 5
            and line.startswith('\t"')
            and not line.split(":")[0].startswith('\t""')
        ):
            file[index] = get_translation(translator, line)

    with open(
        js_path + f"/{lang}_{lang.upper()}.js", "w", encoding="utf-8"
    ) as translated_file:
        translated_file.writelines(file)

    print(f"\n{lang}_{lang.upper()}.js Created")


if __name__ == "__main__":
    lang = sys.argv[1]
    create_language(lang)
