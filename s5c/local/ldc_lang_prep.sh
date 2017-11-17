#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 srcDir dstDir"
  echo "e.g.: $0 inputs_leda data"
  exit 1
fi
src=$1
dst=$2

phoneset=$src/phoneset.txt # monophone_map_leda.txt
lex=$src/lexicon_autogen.1 # Pronlex with variants, in int form, generated by G2P.

[ ! -f $phoneset ] && echo "$0: missing phoneset $phoneset." && exit 1
[ ! -s $phoneset ] && echo "$0: empty phoneset $phoneset."   && exit 1
[ ! -f $lex      ] && echo "$0: missing lexicon $lex."       && exit 1
[ ! -s $lex      ] && echo "$0: empty lexicon $lex."         && exit 1

export LC_ALL=C
odir=$dst # data/local/dict
mkdir -p $odir

# Reformat tabs to spaces. Remove variant numbers.
awk -F'\t' '{if ($1!="" && $4!="") print $1"("$2")",$3,$4}' $lex | sed 's/(0)//g' | sort -k1 -u > $odir/lexiconp.intt

[ ! -s $odir/lexiconp.intt ] && echo "$0: made empty lexicon $odir/lexiconp.intt." && exit 1

# Remove probabilities.
awk '{$2=""; print}' $odir/lexiconp.intt > $odir/lexicon.intt

awk '{print $2}'    $phoneset > $odir/nonsilence_phones.txt
awk '{print $2,$1}' $phoneset > $odir/phonemap.txt
utils/int2sym.pl -f 3- $odir/phonemap.txt $odir/lexiconp.intt | sed 's/ 0.000000 / 0.000001 /' > $odir/lexiconp.txt
# The sed filter rounds up 0.0's to prevent utils/validate_dict_dir.pl from complaining about 0.0's.
# It's only needed for field 2, but the general tool utils/int2sym.pl shouldn't be customized to do that.

cd $odir
echo 'SIL SPN NSN' > extra_questions.txt 
echo -e "SIL\nSPN\nNSN" > silence_phones.txt
echo 'SIL' > optional_silence.txt

cat <<EOT >> lexiconp.txt
SIL 1.0 SIL
!SIL 1.0 SIL
<SPOKEN_NOISE> 1.0 SPN
<UNK> 1.0 SPN
<NOISE> 1.0 NSN
EOT

awk '{$2=""; print}' lexiconp.txt > lexicon.txt
