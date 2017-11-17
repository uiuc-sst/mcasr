#!/usr/bin/python3

# Text filter.
# From STDIN read a pronlex of words whose accents were removed by remove_accents.py.
# On STDOUT write those words+prons with accents restored,
# using the wordmap file made by remove_accents.py,
# to make a new pronlex.

from collections import defaultdict

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('wordmap', type=str, help='Map from original words to de-accented words')
    args = parser.parse_args()

    wordmap = {}
    with open(args.wordmap, 'r') as f:
        for line in f:
           word, norm_word = line.strip().split('\t')
           wordmap[word] = norm_word

    pronD = defaultdict(list)
    for line in sys.stdin:
        norm_word, pron = line.split('\t', 1)
        pronD[norm_word].append(pron)

    for word in sorted(wordmap):
        norm_word = wordmap[word]
        for pron in pronD[norm_word]:
            print(word + '\t' + pron)
