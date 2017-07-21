#!/bin/bash

export LC_ALL=C
MCdict='/ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromWenda/dict_grapheme.txt'
g2pdatadir=data/Uyghur/local/g2p
modelorder=5
pronvariants=5


if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <mc-vocab/dict> <g2p-data-dir>"
  echo "e.g.: $0 /ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromWenda/dict_grapheme.txt data/Uyghur/local/g2p"
  exit 1
fi
if [ "$#" -ge 3 ]; then
    modelorder=$3
fi
if [ "$#" -eq 4 ]; then
    pronvariants=$4
fi
MCdict=$1
g2pdatadir=$2

echo "G2P order : $modelorder    Pronunciation variants : $pronvariants"

mkdir -p $g2pdatadir

if [ ! -f $g2pdatadir/vocab.plain ];then
# first column contains the words
awk '{print $1 }' $MCdict | sort | uniq > $g2pdatadir/vocab.all
# Rm words starting with numbers, rm punctuation marks
egrep -v '^[^a-z]' $g2pdatadir/vocab.all | tr -d '[:punct:]' \
    | uniq >  $g2pdatadir/vocab.plain
fi

# Assuming that G2P is already trained
g2pmodel=${g2pdatadir}_model/model-$modelorder
ls $g2pmodel
[ -f $g2pmodel ] || { echo "$g2pmodel model file is not found."; exit 1; };

./local/g2p_var.sh $g2pdatadir/vocab.plain ${g2pdatadir}_model $g2pdatadir/lexicon_autogen.1 $modelorder $pronvariants

