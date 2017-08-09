#!/usr/bin/python3

# After G2P'ing words without accents, restore the accents.
# Read the map made by remove_accents.py and make a new lexicon.

from collections import defaultdict

def read_word_map(mapfile):
    word_mapD = {}
    with open(mapfile, 'r') as f:
        for line in f:
           w, norm_w = line.strip().split('\t')
           word_mapD[w] = norm_w
    return word_mapD

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('wordmap', type=str,
                        help='Map from original word to the normalized version')
    parser.add_argument('inlex', type=str,
                        help='Input G2P lexicon with normalized words')
    parser.add_argument('outlex', type=str,
                        help='Output G2P lexicon with original words')
    args = parser.parse_args()

    wordMapD = read_word_map(args.wordmap)

    pronD = defaultdict(list)
    with open(args.inlex, 'r') as f:
        for line in f:
            norm_word, pron = line.split('\t', 1)
            pronD[norm_word].append(pron)

    with open(args.outlex, 'w') as outf:
        for word in sorted(wordMapD):
            norm_word = wordMapD[word]
            for pron in pronD[norm_word]:
                outf.write(word+'\t'+pron)
