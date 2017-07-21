import argparse
import csv
from collections import defaultdict
from os import path
import re

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('csv_in', help='Input CSV file, MTurk results', type=str)
    args = parser.parse_args()
    
    # Collect all transcriptions of each audio
    transcript_d = defaultdict(list)
    with open(args.csv_in, 'r') as f:
        csv_d = csv.DictReader(f)
        print(csv_d.fieldnames)
        # for row in csv_d:
        for row in csv_d:
            for n in range(1, 9):
                audio = row['Input.audio'+str(n)]
                transcript = row['Answer.text'+str(n)]
                print (audio, transcript)
                transcript2 = re.sub(r'[.*]', '', transcript)
                print (audio, transcript2)
                break
                # if len(transcript) > 0:
                #     # Get the base name (utt name)
                #     a_bname = path.basename(audio)
                #     a_bname, a_ext = path.splitext(a_bname)
                #     (transcript_d[a_bname]).append(transcript)
                
    # Print text file
    for utt in transcript_d:
        print(utt, transcript_d[utt])
