#! /usr/bin/python3

from collections import defaultdict
from glob import glob
from os import path
import re
import random

# # --- Old version without timing info
# def read_single_file(fname, utt_key=None, delimit='#'):
#     if utt_key == None:
#         bname = path.basename(fname)
#         utt_key, ext = path.splitext(bname)
#     # utt2textD = defaultdict(list) # list of lists
#     textL = []
#     # Each line is a separate list of words
#     # whole doc is a list of lists
#     with open(fname, 'r') as f:
#         for line in f:
#             splitted = line.strip().split(delimit)
#             # Need to replace [*] with UNK?
#             textL.append([re.sub('\[.*?\]', '<UNK>', w.strip())
#                           for w in splitted])
#     return textL 



def read_single_file(fname, utt_key=None, delimit='#', unk_word='', FS=44100.0):
    unk_tag = '<UNK>'
    if utt_key == None:
        bname = path.basename(fname)
        utt_key, ext = path.splitext(bname)
    # print('======', fname)
    textL = [] # list of lists
    # Each line is a separate list of words
    # whole doc is a list of lists
    with open(fname, 'r') as f:
        for line in f:
            line = line.strip()
            if line == '':
                continue
            splitted = line.split(' ', 2)
            # print(splitted)
            if len(splitted ) < 3:
                print('No transcription?/Missing time info?', line)
                continue

            tb, te = splitted[:2]
            words = splitted[2].split(delimit)
            lineList = []
            # Need to replace [*] with UNK?
            for w in words:
                w = w.strip()
                w = re.sub('\[.*?\]', unk_tag, w)
                w = re.sub('\(.*?\)', unk_tag, w)
                if w != '':
                    lineList.append(w)
            if len(lineList) == 0 :
                lineList = [unk_tag] # No transcrption, should we skip?
            # textL.append(lineList)
            try:
                # If line starts with time info
                tb = float(tb)/FS
                te = float(te)/FS
                textL.append(lineList)
            except ValueError:
                continue
    return textL 



def gen_text(textL, N=5):
    # Randomly generate N texts
    gentextL = []
    # At the end it must contain lists of equal length
    for line in textL:
        num_words = len(line)
        wordIDs = list(range(num_words))
        if num_words < N:            
            # sampling with replacement
            word_list = [line[random.choice(wordIDs)] for _ in range(N)]

        elif num_words == N:
            # shuffle
            random.shuffle(wordIDs)
            # print(wordIDs)
            word_list = [line[wordIDs[k]] for k in range(N)]
        else:
            # Pick N
            wordIDs = random.sample(wordIDs, N)
            word_list = [line[k] for k in wordIDs]
        gentextL.append(word_list)
    # Convert to text (row list to column list)
    gentransL = []
    for n in range(N):
        gentransL.append([line[n] for line in gentextL])
    return gentransL
            
def write_text(ofile, utt2textD, keyprefix=''):
    # list of utt2textD
    with open(ofile, 'w') as f:
        for utt in utt2textD:
            for n, text_list in enumerate(utt2textD[utt]):
                uttID = utt+ '_{:03d}'.format(n+1)
                line_text = ' '.join([word for word in text_list])
                f.write(keyprefix+uttID+' '+ line_text + '\n')
                

def write_uttID2baseutt(ofile, utt2textD, keyprefix=''):
    # Since we append digits to the original uttID,
    # we may want to have utt_# utt mapping 
    # then we might convert utt to wav name
    with open(ofile, 'w') as f:
        for utt in utt2textD:
            uttname = keyprefix + utt
            for n in range(len(utt2textD[utt])):
                uttID = uttname+ '_{:03d}'.format(n+1)
                f.write(uttID+' '+uttname+'\n')

            
if __name__ == '__main__':
    filename = '/home/lsari2/data/mcasr/fromCamille/leda/012_001.txt'
    utt_prefix = "IL_DEV3_"
    dirname = "/home/lsari2/data/mcasr/fromCamille/leda/"
    num_transcripts = 5

    import argparse 
    parser = argparse.ArgumentParser()
    parser.add_argument('textdir', type=str, 
                        help='directory for mismatched transcriptions.'
                        'Each file one doc')
    parser.add_argument('outtext', type=str, help='Output text file, probably data/*/text')
    parser.add_argument('-N', type=int, default=5, 
                        help='Number of transcriptions to generate.')
    parser.add_argument('--utt_prefix', type=str, default='', 
                        help='Prefix for utterance IDs, e.g. lang code')
    parser.add_argument('--utt2utt', type=str, default='', 
                        help='File name for extended utt name to original utt name')
    args = parser.parse_args()

    dirname = args.textdir
    ofile = args.outtext
    num_transcripts = args.N
    utt_prefix = args.utt_prefix

    utt2textD = defaultdict(list)
    
    for filename in glob(dirname + '/*.txt'):
        textL = read_single_file(filename)
        bname = path.basename(filename)
        utt_key, ext = path.splitext(bname)
        gentransL = gen_text(textL, num_transcripts)
        utt2textD[utt_key] = gentransL

    # print(utt2textD.keys())
    write_text(ofile, utt2textD, utt_prefix)
    
    # if args.utt2utt != '':
    #     write_uttID2baseutt(args.utt2utt, utt2textD, utt_prefix)
