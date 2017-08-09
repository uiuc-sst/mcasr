#!/bin/bash

export LC_ALL=C
. ./path.sh || exit 1;
. utils/parse_options.sh || exit 1;

model_order=3
pron_variants=5
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 MC_vocab/dict G2P_model phone_set G2P_data_dir"
  echo "e.g.: $0 /ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromWenda/dict_grapheme.txt data/Uyghur/local/g2p"
  exit 1
fi
# if [ "$#" -eq 5 ]; then
#     model_order=$5
# fi
 
MCdict=$1
g2pmodeldir=$2
phoneset=$3
g2pdatadir=$4

[ -f $MCdict ] || { echo "$0: missing nonsense-words file $MCdict"; exit 1; }
[ -d $g2pmodeldir ] || { echo "$0: missing G2P model directory $g2pmodeldir"; exit 1; }

mkdir -p $g2pdatadir

echo "Model order and number of pronunciation variants for G2P application: $model_order $pron_variants"

g2pmodel=$g2pmodeldir/model-$model_order
for f in $g2pmodel $phoneset; do
    [ -f $f ] || { echo "$0: missing file $f"; exit 1; }
    # Copy G2P model and the phone set.
    cp $f ${g2pdatadir}
done

if [ -f $g2pdatadir/vocab.plain ]; then
    # If we run several G2P steps sequentially, overwrite vocab.plain backup.
    echo "Saving $g2pdatadir/vocab.plain as vocab.plain.0."
    mv $g2pdatadir/vocab.plain $g2pdatadir/vocab.plain.0
fi

# first column contains the words
awk '{print $1 }' $MCdict | sort | uniq > $g2pdatadir/vocab.all
# Rm words starting with numbers, rm punctuation marks
egrep -v '^[^a-z]' $g2pdatadir/vocab.all | tr -d '[:punct:]' \
    | uniq >  $g2pdatadir/vocab.plain

# Assuming that G2P is already trained
# cp phoneset and G2P model

ls $g2pmodel
echo "./local/g2p.sh $g2pdatadir/vocab.plain ${g2pdatadir} $g2pdatadir/lexicon_autogen.1 $model_order $pron_variants 2>&1 ${g2pdatadir}/log.$model_order
"
./local/g2p.sh $g2pdatadir/vocab.plain ${g2pdatadir} $g2pdatadir/lexicon_autogen.1 $model_order $pron_variants 2>&1 ${g2pdatadir}/log.$model_order
