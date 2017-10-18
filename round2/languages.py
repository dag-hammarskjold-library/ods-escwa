# encoding: utf-8
# A basic library of UN languages
LANGUAGES = {
  'arabic': { 'short': 'ar', 'mid': 'ara', 'long': 'Arabic', 'orig': 'ﺎﻠﻋﺮﺒﻳﺓ'},
  'chinese': { 'short': 'zh', 'mid': 'chi', 'long': 'Chinese', 'orig': '中文'},
  'english': { 'short': 'en', 'mid': 'eng', 'long': 'English', 'orig': 'English'},
  'french': { 'short': 'fr', 'mid': 'fre', 'long': 'French', 'orig': 'Français'},
  'russian': { 'short': 'ru', 'mid': 'rus', 'long': 'Russian', 'orig': 'Русский'},
  'spanish': { 'short': 'es', 'mid': 'spa', 'long': 'Spanish', 'orig': 'Español'},
  'other': { 'short': 'de', 'mid': 'deu', 'long': 'German','orig':'Deutsch'},
  'ar': 'arabic',
  'zh': 'chinese',
  'en': 'english',
  'fr': 'french',
  'ru': 'russian',
  'es': 'spanish',
  'a': 'arabic',
  'c': 'chinese',
  'e': 'english',
  'f': 'french',
  'r': 'russian',
  's': 'spanish',
}

def resolve_lang(lang):
    try:
        lookup = LANGUAGES[lang.lower()]
    except KeyError:
        raise
    else:
        return_lang = False
        if len(lang) > 2:
            return_lang = lookup
        else:
            return_lang = LANGUAGES[lookup]
        return return_lang