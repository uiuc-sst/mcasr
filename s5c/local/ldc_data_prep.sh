#!/bin/bash

export LC_ALL=en_US.UTF-8

# todo: If $MCTranscriptdir has no *.txt, abort!  Maybe the scrips are accidentally in a subdir.

dst=data/$lang
mkdir -p $dst
for d in $data/$lang_subdir/*/AUDIO; do
  ls $d/*.flac 
done > $dst/all.flist
wavdir=$dst/wav
mkdir -p $wavdir

nbits=16
sox_options="-t flac -r $sample_rate -e signed-integer -b $nbits"
olist=$dst/wav.list
wavscp=$dst/wav.scp
if [ ! -e $wavscp ]; then
  while read line; do 
    bname=$(basename $line)
    bname=${bname%.flac}
    sox $sox_options $line -t wav $wavdir/${bname}.wav

    # Skip any file shorter than 1000 samples.
    nsamples=`soxi -s "$wavdir/${bname}.wav"`
    if [[ "$nsamples" -gt 1000 ]]; then 
      echo "$wavdir/${bname}.wav" >> $olist
      echo "$bname $wavdir/${bname}.wav" >> $wavscp
    fi
  done < $dst/all.flist
fi

if [ -z "$scrip_timing_in_samples" ]; then
  # Transcription timings are in microseconds.
  sfs="--sampling_freq 1e6" # microsec to sec
else
  # Transcription timings are in samples, using $sample_rate.  Old way.
  # From settings_uzb and settings_uyg.
  sfs=""
fi

echo "local/generate_data.py $MCTranscriptdir $dst/segments $dst/vocab $dst/text --utt_prefix $lang_prefix $sfs"
local/generate_data.py $MCTranscriptdir $dst/segments $dst/vocab $dst/text --utt_prefix $lang_prefix $sfs
paste <(cut -d ' ' -f 1 $dst/text) <(cut -d '_' -f 1,2,3 $dst/text ) > $dst/utt2spk
# Because we lack speaker information, utt2spk maps utt to utt.
utils/utt2spk_to_spk2utt.pl $dst/utt2spk > $dst/spk2utt 

tr ' ' '\n' < $dst/vocab | grep -v '<UNK>' > $dst/vocab.words

# Fix any unsorted files.
export LC_ALL=C
utils/data/fix_data_dir.sh $dst

mkdir -p $dst/g2p 
cp $dst/vocab.words $dst/g2p
# cp phoneset $dst/g2p
