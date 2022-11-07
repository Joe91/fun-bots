import sys

from deep_translator import GoogleTranslator

from addons.gets import get_to_root, get_translation
from loguru import logger
from deep_translator.exceptions import (
    LanguageNotSupportedException,
    InvalidSourceOrTargetLanguage,
)


def create_language(lang: str) -> None:
    get_to_root()
    try:
        translator = GoogleTranslator(source="en", target=lang)
    except (LanguageNotSupportedException, InvalidSourceOrTargetLanguage):
        logger.warning(
            "Please select on of the supported languages:\n{'afrikaans': 'af', 'albanian': 'sq', 'amharic': 'am', 'arabic': 'ar', 'armenian': 'hy', 'azerbaijani': 'az', 'basque': 'eu', 'belarusian': 'be', 'bengali': 'bn', 'bosnian': 'bs', 'bulgarian': 'bg', 'catalan': 'ca', 'cebuano': 'ceb', 'chichewa': 'ny', 'chinese (simplified)': 'zh-CN', 'chinese (traditional)': 'zh-TW', 'corsican': 'co', 'croatian': 'hr', 'czech': 'cs', 'danish': 'da', 'dutch': 'nl', 'english': 'en', 'esperanto': 'eo', 'estonian': 'et', 'filipino': 'tl', 'finnish': 'fi', 'french': 'fr', 'frisian': 'fy', 'galician': 'gl', 'georgian': 'ka', 'german': 'de', 'greek': 'el', 'gujarati': 'gu', 'haitian creole': 'ht', 'hausa': 'ha', 'hawaiian': 'haw', 'hebrew': 'iw', 'hindi': 'hi', 'hmong': 'hmn', 'hungarian': 'hu', 'icelandic': 'is', 'igbo': 'ig', 'indonesian': 'id', 'irish': 'ga', 'italian': 'it', 'japanese': 'ja', 'javanese': 'jw', 'kannada': 'kn', 'kazakh': 'kk', 'khmer': 'km', 'kinyarwanda': 'rw', 'korean': 'ko', 'kurdish': 'ku', 'kyrgyz': 'ky', 'lao': 'lo', 'latin': 'la', 'latvian': 'lv', 'lithuanian': 'lt', 'luxembourgish': 'lb', 'macedonian': 'mk', 'malagasy': 'mg', 'malay': 'ms', 'malayalam': 'ml', 'maltese': 'mt', 'maori': 'mi', 'marathi': 'mr', 'mongolian': 'mn', 'myanmar': 'my', 'nepali': 'ne', 'norwegian': 'no', 'odia': 'or', 'pashto': 'ps', 'persian': 'fa', 'polish': 'pl', 'portuguese': 'pt', 'punjabi': 'pa', 'romanian': 'ro', 'russian': 'ru', 'samoan': 'sm', 'scots gaelic': 'gd', 'serbian': 'sr', 'sesotho': 'st', 'shona': 'sn', 'sindhi': 'sd', 'sinhala': 'si', 'slovak': 'sk', 'slovenian': 'sl', 'somali': 'so', 'spanish': 'es', 'sundanese': 'su', 'swahili': 'sw', 'swedish': 'sv', 'tajik': 'tg', 'tamil': 'ta', 'tatar': 'tt', 'telugu': 'te', 'thai': 'th', 'turkish': 'tr', 'turkmen': 'tk', 'ukrainian': 'uk', 'urdu': 'ur', 'uyghur': 'ug', 'uzbek': 'uz', 'vietnamese': 'vi', 'welsh': 'cy', 'xhosa': 'xh', 'yiddish': 'yi', 'yoruba': 'yo', 'zulu': 'zu'}"
        )
        return

    langs_dict = GoogleTranslator().get_supported_languages(as_dict=True)
    lang_name = [k for k, v in langs_dict.items() if v == lang][0].capitalize()

    lua_path = "ext/Shared/Languages"

    with open(lua_path + "/DEFAULT.lua", "r") as template:
        file = template.readlines()

    file[0] = file[0].replace("'xx_XX'", f"'{lang}_{lang.upper()}'")

    logger.info(f"Translating DEFAULT.lua to {lang_name}...")

    for index, line in enumerate(file):
        if line.startswith("Language:add"):
            file[index] = get_translation(translator, line)

    with open(
        lua_path + f"/{lang}_{lang.upper()}.lua", "w", encoding="utf-8"
    ) as translated_file:
        translated_file.writelines(file)

    logger.info(f"{lang}_{lang.upper()}.lua has been built")

    js_path = "WebUI/languages"

    with open(js_path + "/DEFAULT.js", "r") as template:
        file = template.readlines()

    file[0] = file[0].replace("'xx_XX'", f"'{lang}_{lang.upper()}'")
    file[2] = file[2].replace("English", lang_name)
    file[3] = file[3].replace("Unknown", "GoogleTranslator")

    logger.info(f"Translating DEFAULT.js to {lang_name}...")

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

    logger.info(f"{lang}_{lang.upper()}.js has been built")


if __name__ == "__main__":
    lang = sys.argv[1]
    create_language(lang)
