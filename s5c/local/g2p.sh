#!/bin/bash

# Copyright 2014 Vassil Panayotov
# Apache 2.0

# Auto-generates pronunciations using Sequitur G2P

. path.sh || exit 1

[ -z "$PYTHON" ] && PYTHON=python2.7

if [ $# -lt 3 ]; then
  echo "Usage: $0 <vocab> <g2p-model-dir> <out-lexicon> [model-order [num-variants]]"
  echo "  <vocab>: words for which to generate pronunciations, e.g. data/local/dict/g2p/vocab_autogen"
  echo "  <g2p-model-dir>: directory containing the G2P model"
  echo "  <out-lexicon>: the generated pronunciations, e.g. data/\$lang/g2p/lexicon_autogen.1"
  echo "e.g.: $0 data/local/dict/g2p/vocab_autogen.1 /export/a15/vpanayotov/data/g2p data/local/dict/g2p/lexicon_autogen.1"
  exit 1
fi

vocab=$1
g2p_model_dir=$2
out_lexicon=$3

[ ! -f $vocab ] && echo "Missing G2P input file '$vocab'." && exit 1

if [ $# -ge 4 ]; then
    model_order=$4
else
    model_order=2
fi
if [ $# -ge 5 ]; then
    num_variants=$5
else
    num_variants=1
fi

sequitur_model=$g2p_model_dir/model-$model_order
echo "G2P model order: $model_order"
echo "Number of variants to generate: $num_variants"

[ ! -f  $sequitur ] && echo "Missing Sequitur G2P.  See $KALDI_ROOT/tools." && exit 1
[ ! -d $sequitur_path ] && echo "Missing '$sequitur_path'.  Fix the Sequitur installation." && exit 1
[ ! -f $sequitur_model ] && echo "Missing Sequitur model file '$sequitur_model'." && exit 1

# Sequitur incorrectly fails to output pronunciations for some (peculiar) words.
# List these exceptions here, delimited by \n.
g2p_exceptions="HH HH"

PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
  --model=$sequitur_model --apply $vocab --variants-number $num_variants \
  >${out_lexicon}.tmp || exit 1

awk 'NR==FNR{p[$1]=$0; next;} {if ($1 in p) print p[$1]; else print}' \
  <(echo -e $g2p_exceptions) ${out_lexicon}.tmp >$out_lexicon || exit 1

rm ${out_lexicon}.tmp
exit 0
