#!/bin/bash

[ -d $data/$lang_subdir ] || { echo "Missing data/lang_subdir of audio files '$data/$lang_subdir'. Check the settings file. Aborting."; exit 1; }
[ -d $MCTranscriptdir ] || { echo "Missing MCTranscriptdir of transcriptions '$MCTranscriptdir'. Check the settings file. Aborting."; exit 1; }
[[ $(find $MCTranscriptdir -type f -name \*.txt) ]] || { echo "No .txt files in $MCTranscriptdir. Aborting."; exit 1; }

dst=data/$lang
mkdir -p $dst
flist=$dst/all.flist
audioformat=flac
find $data/$lang_subdir -type f -name \*.$audioformat > $flist
if [ ! -s $flist ]; then
  # Found no .flac files.  Instead, find .wav's.
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
# Split the input file $flist, run sox in parallel,
# then recombine the output fragments into $olist and $wavscp.
nparallel=`nproc | sed "s/$/-1/" | bc`	# One fewer than the number of CPU cores.
rm -f $flist.* $olist.* $wavscp.*
split --numeric-suffixes=1 -n r/$nparallel $flist $flist.
for i in `seq -f %02g $nparallel`; do
  (
    while read line; do
      bname=$(basename $line)
      bname=${bname%.$audioformat}
      wav=$wavdir/${bname}.wav
      sox -t $audioformat -r $sample_rate -e signed-integer -b 16 $line -t wav $wav
      if [[ $(( $(soxi -s $wav) )) -lt 1000 ]]; then 
	# This file has fewer than 1000 samples.  Skip it.
	rm $wav
      else
	echo $wav >> $olist.$i
	echo $bname $wav >> $wavscp.$i
      fi
    done < $flist.$i
  ) &
done
wait
sort $olist.* > $olist
sort $wavscp.* > $wavscp
rm -f $flist.* $olist.* $wavscp.*

if [[ -z $lang_prefix ]]; then
  utt_prefix=
else
  utt_prefix="--utt_prefix $lang_prefix"
fi

if [ -z "$scrip_timing_in_samples" ]; then
  # Transcription timings are in microseconds.
  sfs="--sampling_freq 1e6" # microsec to sec
else
  # Transcription timings are in samples, using $sample_rate.  Old way.
  # From settings_uzb and settings_uyg.
  sfs=""
fi

export LC_ALL=en_US.UTF-8

echo "local/generate_data.py $MCTranscriptdir $olist $dst/segments $dst/vocab $dst/text $utt_prefix $sfs"
local/generate_data.py $MCTranscriptdir $olist $dst/segments $dst/vocab $dst/text $utt_prefix $sfs
[ -s $dst/vocab ] || { echo "local/generate_data.py made empty word list $dst/vocab. Aborting."; exit 1; }
paste <(cut -d ' ' -f 1 $dst/text) <(cut -d '_' -f 1,2,3 $dst/text ) > $dst/utt2spk
# Because we lack speaker information, utt2spk maps utt to utt.
utils/utt2spk_to_spk2utt.pl $dst/utt2spk > $dst/spk2utt 

# If $dst/vocab is empty, then grep gets empty input and returns nonzero, which aborts the script because of "set -e".
tr ' ' '\n' < $dst/vocab | grep -v '<UNK>' > $dst/vocab.words

# Fix any unsorted files.
export LC_ALL=C
utils/data/fix_data_dir.sh $dst

mkdir -p $dst/g2p 
cp $dst/vocab.words $dst/g2p
# cp phoneset $dst/g2p
