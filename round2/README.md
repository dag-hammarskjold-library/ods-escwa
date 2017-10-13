# Steps
1. Git clone this repo and cd into ods-escwa/round2

```git clone https://github.com/dag-hammarskjold-library/ods-escwa && cd ods-escwa/round2```
    
2. Install python virtualenv. Ensure you have Python 3.6+

```virutalenv -p python3.6 venv```

3. Install python requirements. Note that the version of PyMARC is currently fixed.

```pip install -r requirements.txt```

4. (OPTIONAL) rerun mapping of the authorities that exist in the ODS structured text.

```python makeauth.py```

5. Make the metadata.

```python makemeta.py```

6. Inspect your metadata.xml and, if necessary, clean up erroneous Unicode characters. You can detect these using xmllint, which also allows you to reformat the XML (pretty print, basically).

```xmllint --format --encode utf-8 metadata.xml > metadata_formatted.xml```

# Notes
I was seeing errors like the following when running xmllint:

```
metadata.xml:82: parser error : Premature end of data in tag collection line 2
ETY IN THE ARAB REGION : ECONOMIC AND SOCIAL COMMISSION FOR WESTERN ASIA (ESCWA)
```

The cause was some kind of null character in the middle of the text. There were many of these, and the only way I found to correct it was to open the XML in my editor and do a find and replace on that particular character. There is undoubtedly a direct pythonic way to do this.
