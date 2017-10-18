#!/bin/bash

# Extract nonsense words from a too-big pronunciation dictionary, whose lines have the form
#     a'laahamaschi a l a ah a m a sc h i
#     a'laahamaschi a l aa h a m a s c h i
#		(from dict_grapheme.txt)
# or
#     alaamgili 0.14373  a l aa m gi l i
#     alaamgili 0.05287 al a a m g i l i
#		(from normal_dict_prob.txt)
#
# Usage: ./get-words.sh < in.txt > dict_words.txt

# This gets the first word of each input line,
# and removes duplicates that are due to multiple pronunciations per word.

# The rest of this pipeline typically reduces 331k words to 328k words:
#
# Strips erroneous turker-ids like 39aygo6afff1jfkd6lcxd96yy24n6k", that begin with a digit.
# Assumes that everything is lower case.
# Converts to spaces everything except a-z and apostrophe.
# Removes consecutive spaces.
# Puts each word on its own line.
# Removes fresh duplicates.

cut -f 1 -d ' ' | sort -u | \
    grep -v "^[0-9]" | sed "s/[^a-z']/ /g" | sed "s/\s+/ /g" | sed "s/ /\n/g" | sort -u
