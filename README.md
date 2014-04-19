# nerdz-translator
_ultimate all-in-one translator for NERDZ strings_

This program quickly translates a string in multiple languages,
making localization a process much more easier and fun. There are
lots of options which are thoughtfully documented in this manual.

Setting up the script
-------------

Before using this script you need to configure it in the source file.

Please open the main source file (`nerdz_translator.pl`) and start
reading at line 18. Don't worry, you don't need any Perl knowledge.

Usage
-----

    nerdz-translator [options] [-k key] [string_to_translate]

    Options:
      -i                   The input language.
      -o                   Comma-separated list of output languages.
      -k                   A key which represents the string you are translating.
      -l                   Shows a list of available languages, then exits.
      -O                   Enables direct output mode.
      -f                   The JSON file which will be edited if directout is on.
      -v                   Version information.
      -h                   This short help text.
      --manual             The full help text. Also available with perldoc.
      --output-format      The format string used as the output for each language
      --output-file-format Used to determine the path of the language files.
      --set-translation    Manually sets translations of different languages.

Available options
-----

- __--translate-from__, __-i__ _language_

    Specifies the input language. The default is 'en'.

- __--translate-to__, __-o__ _language-1,language-2,..._

    Comma-separated list of output languages.
    The default is 'de',&nbsp;'hr',&nbsp;'en',&nbsp;'pt',&nbsp;'ro'.

- __--key__, __-k__ _KEY_

    A key which represents the string you are translating in a short form.
    Like `ERR_DUMB_USER`.

    __This parameter is required.__

- __--output-format__ _format-string_

    The format string used as the output for each language.
    Not used when __--output-dir__, __-o__ is specified.

    Available variables:

    - __=translated__

        The translated string.

    - __=qtranslated__

        The translated string with quotes.

    - __=to__

        The language the string is being translated into.

    - __=key__

        The key specified with __--key__, __-k__.

    - __=n__

        A newline.

    Default: `=to=n"=key":&nbsp;=qtranslated`

    Which produces an output like:

        language_name
        "key": "value"

- __--output-file-format__ _format-string_

    The format string used to determine the final path of the language files.
    This is used only if __--output-dir__, __-o__ is specified.

    Available variables:

    - __=outdir__

        The value of __--output-dir__, __-o__.

    - __=outfn__

        The value of __--output-file__, __-f__ (or the default value).

    - __=lang__

        The language the string is being translated into.

    Default: `=outdir/=lang/json/=outfn`

- __-l__

    Shows a list of available languages. Exits immediately afterwards.

- __--output-dir__, __-O__ _directory_

    Enables the file output mode. It reads the JSON files with the names
    specified in the __--output-file__, __-f__ option (or the default value)
    and appends the traditional JSON "key": "value" mapping.

    __NOTE:__ The JSON files are read and written by the Perl's JSON module.
    This means that your indentation, comments or any custom stuff which is
    not pure JSON __will probably be deleted__. However, the parser outputs
    a pretty 4-spaces indented JSON which should be nice to read.

- __--output-file__, __-f__ _file_

    The JSON file which will be edited if __--output-dir__, __-O__ is specified.
    The final path of the JSON files will be determined by the value of
    __--output-file-format__. The default value is `default.json`.

- __--set-translation__ _language-name_ _`translation`_

    This option manually sets the translation for _language-name_ to
    _translation_. It is __recommended__ to specify the _translation_ parameter
    with the quotes, and it is __mandatory__ if your translation contains spaces.

    This parameter is useful when you need the translation of your native
    language too. Let's say that I'm an Italian native-speaker and I'm translating
    in three different languages. Here's a command line which handles Italian too
    without automatic translation:

        nt -i en -o ro,hr,jp -k SOMETHING --set-translation it "Sì" Yes

- __--version__, __-v__

    Shows the version of this program, Perl and Getopt.

- __--help__, __-h__

    The short version of this manual.

- __--manual__

    The full version of this manual.

Examples
------

All the examples assume `nt` as the executable file `nerdz-translator.pl`.

- Basic translation with `NO_THANKS` as the key

        nt -k "NO_THANKS" "No thanks"

- Changing the source language

        nt -i it -k "NO_THANKS" "No grazie"

- Changing the target languages

        nt -i it -o en,ro -k "NO_THANKS" "No grazie"

- Changing the output format

        nt -i it -o en,ro -k "NO_THANKS" --output-format "=translated=n" "No grazie"

- Outputting to JSON files

        nt -i it -o en,ro -k "NO_THANKS" -O "path/to/langs" "No grazie"

- Outputting to JSON files named `tst.json`

        nt -i it -o en,ro -k "NO_THANKS" -O "path/to/langs" -f "tst.json" "No grazie"

- Setting the translation for English

        nt -i it -o ro -k "YES" --set-translation en "Yes" "Si"

- Changing the output file format

        nt -k "YES" -O "some/path" --output-file-format "=outdir/=lang/=outfn" "Yes"

- Showing the available languages from Bing

        nt -l

TODO
----

- Use a JSON file for the configuration?

Author
-----

Roberto Frenna <<robertof.public@gmail.com>>

Copyright and license
-----------

Copyright 2014 Roberto Frenna

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
