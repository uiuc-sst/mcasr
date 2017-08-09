#!/usr/bin/python3

from collections import defaultdict
from glob import glob
from os import path
import re
import random

def read_single_file(fname, utt_key=None, delimit='#', unk_word='', FS=44100.0):
    unk_tag = '<UNK>'
    if utt_key == None:
        bname = path.basename(fname)
        utt_key, ext = path.splitext(bname)
    textL = [] # list of lists
    # Each line is a separate list of words.
    # Whole doc is a list of lists.
    with open(fname, 'r') as f:
        for line in f:
            line = line.strip()
            if line == '':
                continue
            splitted = line.split(' ', 2)
            if len(splitted ) < 3:
                print('In file', fname, 'skipping too-short line:', line)
                continue

            tb, te = splitted[:2]
            words = splitted[2].split(delimit)
            lineList = []
            # Need to replace [*] with UNK?
            for w in words:
                w = re.sub('\[.*?\]', unk_word, w.strip())
                if w != '':
                    lineList.append(w)
            if len(lineList) == 0 :
                lineList = [unk_tag] # No transcrption, should we skip?
            try:
                tb = float(tb)/FS
                te = float(te)/FS
                textL.append((tb, te, lineList))
            except ValueError:
                continue
    return textL 

if __name__ == '__main__':
    import argparse 
    parser = argparse.ArgumentParser()
    parser.add_argument('textdir', type=str, 
                        help='directory for mismatched transcriptions. '
                        'Each file one doc')
    parser.add_argument('segments', type=str, 
                        help='Output segments file for Kaldi setup '
                        'utt file tb te (in sec)')
    parser.add_argument('vocab', type=str, 
                        help='(Nonsense) Word list, '
                        ' will be input for G2P for lexicon generation')    
    parser.add_argument('textout', type=str, 
                        help='Mismatched transcriptions per utterance '
                        'a.k.a Kaldi data/text, maps utterance to text')
    parser.add_argument('--unknown_word', type=str, default='<UNK>',
                        help='String to use for unknown/untranscribed segments '
                        '[noise] -> <UNK>')
    parser.add_argument('--sampling_freq', type=float, default=44100.0,
                        help='Sampling frequency of the audio')
    parser.add_argument('--utt_prefix', type=str, default='', 
                        help='Prefix for utterance IDs, e.g. lang code')
    args = parser.parse_args()
        
    dirname = args.textdir
    unknown_word = args.unknown_word
    utt_prefix = args.utt_prefix
    if utt_prefix!='' and utt_prefix[-1] != '_':
        utt_prefix += '_'

    segf = open(args.segments, 'w')
    textf = open(args.textout, 'w')

    wordSet = set()
    for filename in glob(dirname + '/*.txt'):
        textL = read_single_file(filename, unk_word=unknown_word, FS=args.sampling_freq)
        bname = path.basename(filename)
        file_key, ext = path.splitext(bname)
        file_key = utt_prefix+file_key
        for tb, te, words in textL:
            # sec to msec or to microsec, keep time info in the utterance name
            if args.sampling_freq == 44100.0:
                foo = '{}_{:06d}_{:06d}'
                scale = 1000
            else:
                # args.sampling_freq == 1e6:  actually what's in microseconds is timing info in the transcriptions, not the audio data.
                foo = '{}_{:09d}_{:09d}'
                scale = 1e6
            utt_base_key = foo.format(file_key, round(tb*scale), round(te*scale))
            # n = 0
            for n, w in enumerate(words):
                utt_key = utt_base_key  + '_{:03d}'.format(n+1)
                textf.write(utt_key + ' ' + w + '\n' )
                if w != unknown_word:
                    wordSet.update([x for x in w.split(' ') if x.find(unknown_word)==-1])
                segf.write('{} {} {:.6f} {:.6f}\n'.format(utt_key, file_key, tb, te))

    segf.close()
    textf.close()

    # Write words 
    with open(args.vocab, 'w') as f:
        for word in wordSet:
            # '\n'.join([w for w in word.split() if (w!='' and w != unknown_word) ])
            f.write(word+'\n')
