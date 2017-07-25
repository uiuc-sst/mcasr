#! /bin/bash

basedatadir=/ws/ifp-53_1/hasegawa/lsari2/data/speech_data1
datadir=$basedatadir/Uzbek/LDC2016E66/UZB_20160711
lang=Uzbek
transcriptdir=/ws/ifp-53_1/hasegawa/lsari2/data/mcasr/leda-uzbek
pref='' # 'UZB'
odir='data/$lang/data'

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 srcDir MCTranscriptDir dstDir [lang-prefix]"
  echo "e.g.: $0 Uzbek/LDC2016E66/UZB_20160711 fromCamille/leda-uzbek data/LDC2016E66 UZB"
  exit 1
fi
if [ "$#" -eq 4 ]; then
  pref=$4
fi 

# Base dir for audio data.
basedatadir=$(cat DATA_ROOT.txt)

src=$basedatadir/$1
transcriptdir=$2
dst=$3

export LC_ALL=en_US.UTF-8

mkdir -p $dst
for d in $src/*/AUDIO; do
  ls $d/*.flac 
done > $dst/all.flist

fs=44100
nbits=16
sox_options="-t flac -r $fs -e signed-integer -b $nbits"

wavdir=$dst/wav
olist=$dst/wav.list
wavscp=$dst/wav.scp

mkdir -p $wavdir

if [ ! -e $wavscp ]; then
  while read line; do 
    bname=$(basename $line)
    bname=${bname%.flac}
    sox $sox_options $line -t wav $wavdir/${bname}.wav

    nsamples=`soxi -s "$wavdir/${bname}.wav"`;
    # Check if the file is too short, less than 1000 samples
    if [[ "$nsamples" -gt 1000 ]]; then 
      echo "$wavdir/${bname}.wav" >> $olist;
      echo "$bname $wavdir/${bname}.wav" >> $wavscp
    fi
  done < $dst/all.flist
fi

echo "local/generate_data.py $transcriptdir $dst/segments $dst/vocab $dst/text --utt_prefix $pref;"
local/generate_data.py $transcriptdir $dst/segments $dst/vocab $dst/text --utt_prefix $pref;
# utt2spk? 
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
