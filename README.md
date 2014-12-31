Chinese Study Data
==================

A script and (source) data used to make CSV files for flash cards.

It's quick and dirty, and only does minor sanitization to clean up the
definitions that end up in the final CSV files I used for flash cards;
after that I just more or less manually cleaned them up as I studied.
Feel free to use it however you want, but don't bother complaining to
me if the result is crap.

Includes data files (from CEDICT, HSK word list, and some frequency data) that
are required by the script to generate the final CSV files.  You may
want newer data, but the included files are probably good enough.

* convert.rb : actual script
* HSK-2012.csv : HSK word list and levels
* cedict_ts.u8 : CEDICT dictionary data (see [http://www.mdbg.net/chindict/chindict.php?page=cedict](http://www.mdbg.net/chindict/chindict.php?page=cedict))
* SUBTLEX-CH-* : frequency data (see [http://expsy.ugent.be/subtlex-ch/](http://expsy.ugent.be/subtlex-ch/))

Needs my pinyin tone converter (see [https://github.com/doubt72/pinyin-tone-converter](https://github.com/doubt72/pinyin-tone-converter)), the just grab the
`pinyin_tone_converter.rb` script itself and stick it in the same directory.

The final result is three CSV files, one for vocabulary, and two for
characters (one with all the characters from the vocabulary list, the
other with just the simplified-traditional differences).