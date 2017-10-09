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
    textL = []
    # Each line of fname is a beginTime, endTime, and list of words;
    # so textL becomes a list of lists.
    with open(fname, 'r') as f:
        for line in f:
            line = line.strip()
            if line == '':
                continue
            splitted = line.split(' ', 2)
            if len(splitted) < 3:
                print(__file__, "warning: skipping incomplete line '"+line+"' in file", fname)
                continue

            tBegin, tEnd = splitted[:2]
            words = splitted[2].split(delimit)
            lineList = []
            # Need to replace [*] with UNK?
            for w in words:
                w = re.sub('\[.*?\]', unk_word, w.strip())
                if w != '':
                    lineList.append(w)
            if not lineList:
                lineList = [unk_tag] # No transcription, should we skip?
            try:
                tBegin = float(tBegin)/FS
                tEnd = float(tEnd)/FS
                if tBegin >= tEnd:
                    print(__file__, "warning: skipping reversed-time line '"+line+"' in file", fname)
                    continue
                textL.append((tBegin, tEnd, lineList))
            except ValueError:
                print(__file__, "warning: skipping corrupt line '"+line+"' in file", fname)
                continue
    if not textL:
        print(__file__, "warning: corrupt file", fname)
    return textL 

if __name__ == '__main__':
    # https://docs.python.org/3/library/argparse.html#the-add-argument-method
    import argparse 
    parser = argparse.ArgumentParser()
    parser.add_argument('textdir', type=str, 
                        help='Input: directory of transcriptions, one file per utterance. ')
    parser.add_argument('wavsIn', type=str, 
                        help='Input: list of utterance .wav\'s, one per line. ')
    parser.add_argument('segments', type=str, 
                        help='Output: segments file for Kaldi setup, each line contains:'
                        'utt_key file_key sec_begin sec_end')
    parser.add_argument('vocab', type=str, 
                        help='Output: list of nonsense words, for G2P to generate lexicon')
    parser.add_argument('textout', type=str, 
                        help='Output: mismatched transcriptions per utterance '
                        'a.k.a Kaldi data/text, maps utterance to text')
    parser.add_argument('--unknown_word', type=str, default='<UNK>',
                        help='String to use for unknown/untranscribed segments '
                        '[noise] -> <UNK>')
    parser.add_argument('--sampling_freq', type=float, default=44100.0,
                        help='Units of timing offsets (1/s)')
    parser.add_argument('--utt_prefix', type=str, default='', 
                        help='Prefix for utterance IDs, e.g. lang code')
    args = parser.parse_args()
        
    unknown_word = args.unknown_word
    utt_prefix = args.utt_prefix
    if utt_prefix!='' and utt_prefix[-1] != '_':
        utt_prefix += '_'

    with open(args.wavsIn) as f:
        wavsIn = [path.basename(x.rstrip('\n')) for x in f.readlines()]
    segf = open(args.segments, 'w')
    textf = open(args.textout, 'w')

    wordSet = set()
    for filename in glob(args.textdir + '/*.txt'):
        file_key, ext = path.splitext(path.basename(filename))
        # todo: for much faster lookup, instead of "in wavsIn", convert wavsIn to a set.
        if not (file_key + ".wav") in wavsIn:
            print(__file__, "warning: skipping transcription "+filename+" that isn't mentioned in", args.wavsIn)
            continue
        file_key = utt_prefix+file_key
        textL = read_single_file(filename, unk_word=unknown_word, FS=args.sampling_freq)
        for tBegin, tEnd, words in textL:
            # sec to msec or to microsec, keep time info in the utterance name
            if args.sampling_freq == 44100.0:
                foo = '{}_{:06d}_{:06d}'
                scale = 1000
            else:
                # args.sampling_freq == 1e6:  actually what's in microseconds is timing info in the transcriptions, *not* the audio's sample rate.
                foo = '{}_{:09d}_{:09d}'
                scale = 1e6
            utt_base_key = foo.format(file_key, round(tBegin*scale), round(tEnd*scale))
            for n, w in enumerate(words):
                utt_key = utt_base_key  + '_{:03d}'.format(n+1)
                textf.write(utt_key + ' ' + w + '\n' )
                if w != unknown_word:
                    wordSet.update([x for x in w.split(' ') if x.find(unknown_word)==-1])
                segf.write('{} {} {:.6f} {:.6f}\n'.format(utt_key, file_key, tBegin, tEnd))

    segf.close()
    textf.close()
    if not wordSet:
        print(__file__, "warning: no transcriptions in", args.textdir + '/*.txt.')

    # Write the word list.
    with open(args.vocab, 'w') as f:
        for word in wordSet:
            # '\n'.join([w for w in word.split() if (w!='' and w != unknown_word) ])
            f.write(word+'\n')
