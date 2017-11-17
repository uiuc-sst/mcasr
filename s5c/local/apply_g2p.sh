#!/bin/bash

# Apply G2P with a second-order (bigram) model.
# Retry any failed words with a first-order (unigram) model.
# Retry any still-failed words by removing their accents.
# In all three cases, call generate_vocab.sh.
# On stdout write the generated lexicon, as the cases' concatenation
# (run.sh writes this script's STDOUT into $dd/lexicon_autogen.1).

# Default values for parse_options.sh.
pron_variants=5
g2p_model_dir=inputs/g2p_reduced_model
phoneset=inputs/phoneset.txt # Includes OOV symbol.

. ./path.sh || exit 1
. utils/parse_options.sh || exit 1

[ "$#" -lt 4 ] && >&2 echo "Usage: $0 mc-vocab/dict G2P-model phone-set g2p-data-dir" && exit 1
 
MCdict=$1
g2p_model_dir=$2
phoneset=$3
dd=$4 # Data dir.

mkdir -p $dd
# $gen creates $dd/lexicon_autogen.1, which we then modify.
alias gen="local/generate_vocab.sh --pron_variants $pron_variants $g2p_model_dir $phoneset $dd"
alias findfailed="grep failed | cut -d ':' -f 1 | cut -d ' ' -f 4 | sed 's/\"//g'"
export LC_ALL=en_US.UTF-8

# Apply G2P, using an already-trained bigram G2P model.
$gen --model_order 2 < $MCdict &> $dd/log.2
cat $dd/lexicon_autogen.1
[ $(grep -c failed $dd/log.2) -le 0 ] && exit 0
# There were failure cases, so retry those with a unigram G2P model.

findfailed < $dd/log.2 | $gen --model_order 1 &> $dd/log.1
cat $dd/lexicon_autogen.1
[ $(grep -c failed $dd/log.1) -le 0 ] && exit 0
# There were still failure cases, so retry those with accents removed.

findfailed < $dd/log.1 | local/remove_accents.py $dd/word.map | $gen --model_order 1 &> $dd/log.0
local/convert_words.py $dd/word.map < $dd/lexicon_autogen.1
