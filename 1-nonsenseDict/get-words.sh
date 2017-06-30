#!/bin/bash
#
# Extract nonsense words from a too-big pronunciation dictionary, whose lines have the form
# a'laahamaschi a l a ah a m a sc h i
# a'laahamaschi a l aa h a m a s c h i
#
# Usage: ./get-words.sh < dict_grapheme.txt > dict_words.txt

# This gets the first word of each input line,
# and removes duplicates due to multiple pronunciations per word.

# The rest of this pipeline typically reduces 331k words to 328k words:
#
# Strips erroneous turker-ids like 39aygo6afff1jfkd6lcxd96yy24n6k", that begin with a digit.
# Assumes that everything is lower case.
# Converts to spaces everything except a-z and apostrophe.
# Removes consecutive spaces.
# Puts each word on its own line.
# Removes fresh duplicates.

awk '{print $1}' | sort -u | \
    grep -v "^[0-9]" | sed "s/[^a-z']/ /g" | sed "s/\s+/ /g" | sed "s/ /\n/g" | sort -u
