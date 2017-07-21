#! /usr/bin/env python3

from sys import argv,exit
from collections import defaultdict

X = 'X' # unknown mapping

def read_g2p_map(g2pfile):
    g2pD = defaultdict(str)
    with open(g2pfile, 'r') as f:
        for line in f:
            splitted = line.strip().split(' ')
            if len(splitted) < 2:
                print('Wrong file format. must have at least two columns. Skipping')
                continue
            # Keeps the last element but there are alternative versions !!!
            g2pD[splitted[0]] = ' '.join([p for p in splitted[1:] if p!=''])
    return g2pD
        
def convert_grapheme_dict(gdict_prob_file, g2p_dict, pdict_ofile):
    # WORD PROB GRAPH SEQ
    word2intD = defaultdict(list)
    with open(gdict_file, 'r') as f:
        with open(pdict_ofile, 'w') as outf:
            for line in f:
                splitted = line.strip().split()
                if len(splitted) < 3:
                    print ('there are missing columns in the line', line)
                    print ('Skipping')
                    continue
                word, prob, graphemes = splitted[0], splitted[1], splitted[2:]
                phones = ' '.join([g2p_dict[g] if g in g2p_dict else X for g in graphemes])
                # do not write duplicate pronunciations
                if phones not in word2intD[word]:
                    outf.write('{} {} {}\n'.format(word, prob, phones))
                    word2intD[word].append(phones)


if __name__ == '__main__':
    if len(argv) < 4:
        print ('Error: Missing args: g2p grapheme-dict phonetic-dict-out')
        exit(1)
    g2p_file = argv[1]
    gdict_file = argv[2]
    pdict_ofile = argv[3]

    g2p_dict = read_g2p_map(g2p_file)
    print(g2p_dict)
    convert_grapheme_dict(gdict_file, g2p_dict, pdict_ofile)
    
    
