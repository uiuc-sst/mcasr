#!/bin/bash

export LC_ALL=en_US.UTF-8

# todo: If $MCTranscriptdir has no *.txt, abort!  Maybe the scrips are accidentally in a subdir.

[ -d $data/$lang_subdir ] || { echo "Missing data/lang_subdir of audio files '$data/$lang_subdir'. Check the settings file. Aborting."; exit 1; }
[ -d $MCTranscriptdir ] || { echo "Missing MCTranscriptdir of transcriptions '$MCTranscriptdir'. Check the settings file. Aborting."; exit 1; }

find $MCTranscriptdir -type f -name \*.txt > /tmp/$$
[ -s /tmp/$$ ] || { echo "No .txt files in $MCTranscriptdir. Aborting."; rm /tmp/$$; exit 1; }
rm /tmp/$$

dst=data/$lang
mkdir -p $dst
flist=$dst/all.flist
audioformat=flac
find $data/$lang_subdir -type f -name \*.$audioformat > $flist
if [ ! -s $flist ]; then
  # Found no .flac files.  Try .wav instead.
  audioformat=wav
  find $data/$lang_subdir -type f -name \*.$audioformat > $flist
fi
if [ ! -s $flist ]; then
  echo "No .flac or .wav files in '$data/$lang_subdir'. Aborting."
  rm $flist
  exit 1
fi

# Rebuild $wavdir, $olist, and $wavscp from $flist, even if those already exist.
wavdir=$dst/wav
olist=$dst/wav.list
wavscp=$dst/wav.scp
rm -rf $wavdir; mkdir -p $wavdir
>| $olist
>| $wavscp
while read line; do 
  bname=$(basename $line)
  bname=${bname%.$audioformat}
  wav=$wavdir/${bname}.wav
  sox -t $audioformat -r $sample_rate -e signed-integer -b 16 $line -t wav $wav

  # Skip any file shorter than 1000 samples.
  nsamples=`soxi -s "$wav"`
  if [[ "$nsamples" -gt 1000 ]]; then 
    echo $wav >> $olist
    echo $bname $wav >> $wavscp
  fi
done < $flist

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
