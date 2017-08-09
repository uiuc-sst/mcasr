#!/usr/bin/python3

# Remove accents from a list of words.
# Create a de-accented word list, and a file that maps
# original words to de-accented words, which will be read
# by convert_words.py to restore the accents.

import re
# from collections import defaultdict
import unicodedata

def strip_accents(s):
    # for c in unicodedata.normalize('NFKD', s) :
    #     print(unicodedata.category(c))
    categories = ['Lm', 'Sk', 'Mn', 'Po', 'Z']
    chars = []
    for c in unicodedata.normalize('NFD', s) :
        cur_catg = unicodedata.category(c)
        if all([(cur_catg != category) for category in categories]):
            chars.append(c)
    return ''.join(chars)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('invocab', type=str,
                        help='Input vocabulary: list of words to which G2P will be applied')
    parser.add_argument('outvocab', type=str,
                        help='Output vocabulary: invocab without accents')
    parser.add_argument('wordmap', type=str,
                        help='Map from original word to the normalized version')
    args = parser.parse_args()

    wordMapD= {}
    with open(args.invocab, 'r') as f:
        with open(args.outvocab, 'w') as outf:
            for line in f:
                line=line.strip()
                # print(line)
                mod_line = strip_accents(line)
                outf.write(mod_line+'\n')
                wordMapD[line] = mod_line

    with open(args.wordmap, 'w') as f:
        for line, normline in wordMapD.items():
            f.write(line + '\t' + normline + '\n')
