#!/usr/bin/python3

# Text filter.  From STDIN read a list of words.
# On STDOUT write those words with accents removed.
# Create a wordmap file that maps the original words to de-accented words,
# which will be read by convert_words.py to restore the accents.

import re
import unicodedata

def strip_accents(s):
    # for c in unicodedata.normalize('NFKD', s):
    #     print(unicodedata.category(c))
    categories = ['Lm', 'Sk', 'Mn', 'Po', 'Z']
    chars = []
    for c in unicodedata.normalize('NFD', s):
        cur_catg = unicodedata.category(c)
        if all([(cur_catg != category) for category in categories]):
            chars.append(c)
    return ''.join(chars)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('wordmap', type=str, help='Map from original words to de-accented words')
    args = parser.parse_args()

    wordmap= {}
    for line in sys.stdin:
        mod_line = strip_accents(line.strip())
        print(mod_line)
        wordmap[line] = mod_line

    with open(args.wordmap, 'w') as f:
        for line, normline in wordmap.items():
            f.write(line + '\t' + normline + '\n')
