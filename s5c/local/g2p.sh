#!/bin/bash

# Copyright 2014 Vassil Panayotov
# Apache 2.0

# Auto-generates pronunciations using Sequitur G2P

. path.sh || exit 1

[ -z "$PYTHON" ] && PYTHON=python2.7

if [ $# -lt 3 ]; then
  echo "Usage: $0 <vocab> <g2p-model-dir> <out-lexicon> [model-order [num-variants]]"
  echo "e.g.: $0 data/local/dict/g2p/vocab_autogen.1 /export/a15/vpanayotov/data/g2p data/local/dict/g2p/lexicon_autogen.1"
  echo ", where:"
  echo "    <vocab> - input vocabulary, that's words for which we want to generate pronunciations"
  echo "    <g2p-model-dir> - source directory where g2p model is located"
  echo "    <out-lexicon> - the output, i.e. the generated pronunciations"
  exit 1
fi

vocab=$1
g2p_model_dir=$2
out_lexicon=$3

[ ! -f $vocab ] && echo "Can't find the G2P input file: $vocab" && exit 1;

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

# Turns out, that Sequitur has some sort of bug so it doesn't output pronunciations
# for some (admittedly peculiar) words. We manually specify these exceptions below
g2p_exceptions="HH HH" # more such entries can be added, separated by "\n"

[ ! -f  $sequitur ] && \
  echo "Can't find the Sequitur G2P script. Please check $KALDI_ROOT/tools for installation script and instructions" && \
  exit 1;

[ ! -d $sequitur_path ] && echo "Can't find '$sequitur_path' - please fix your Sequitur installation" && exit 1
[ ! -f $sequitur_model ] && echo "Can't find the Sequitur model file: $sequitur_model" && exit 1

PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
  --model=$sequitur_model --apply $vocab --variants-number $num_variants \
  >${out_lexicon}.tmp || exit 1


awk 'NR==FNR{p[$1]=$0; next;} {if ($1 in p) print p[$1]; else print}' \
  <(echo -e $g2p_exceptions) ${out_lexicon}.tmp >$out_lexicon || exit 1

rm ${out_lexicon}.tmp
exit 0
