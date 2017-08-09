#!/bin/bash

# Apply G2P with a second-order model.
# Retry any failed words, with a first-order model.
# Retry any still-failed words with accents removed.
# In all 3 cases, call generate_vocab.sh.
# The final lexicon is the concatenation of all 3,
# namely $g2pdatadir/lexicon_autogen.1

model_order=2
pron_variants=5
g2p_model_dir=inputs/g2p_reduced_model
phoneset=inputs/phoneset.txt # Includes OOV symbol

. ./path.sh || exit 1;
. utils/parse_options.sh || exit 1;

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <mc-vocab/dict> <G2P-model> <phone-set> <g2p-data-dir>"
  echo "e.g.: $0 /ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromWenda/dict_grapheme.txt data/Uyghur/local/g2p"
  exit 1
fi
# if [ "$#" -eq 5 ]; then
#     model_order=$5
# fi
 
MCdict=$1
g2pmodeldir=$2 # should be g2p_model_dir?
phoneset=$3
g2pdatadir=$4

mkdir -p $g2pdatadir

export LC_ALL=en_US.UTF-8

# Apply G2P, assuming that we have already trained a G2P model.
local/generate_vocab.sh --model_order 2 --pron_variants $pron_variants $MCdict $g2p_model_dir $phoneset $g2pdatadir &> $g2pdatadir/log.2
echo "Generate vocab using a bigram model: Done"
mv $g2pdatadir/lexicon_autogen.1 $g2pdatadir/lexicon_autogen.bi

# If there are failure cases, back off to a unigram G2P model.
if [ $(grep -c failed $g2pdatadir/log.2) -gt 0 ]; then
    # mv $g2pdatadir/lexicon_autogen.1  $g2pdatadir/lexicon_autogen.bi
    MCdictfail=$g2pdatadir/vocab.fail.1
    grep failed $g2pdatadir/log.2 | cut -d ':' -f 1 | cut -d ' ' -f 4 |sed 's/\"//g' > $MCdictfail
    local/generate_vocab.sh --model_order 1 --pron_variants $pron_variants $MCdictfail $g2p_model_dir $phoneset $g2pdatadir &> $g2pdatadir/log.1
    mv $g2pdatadir/lexicon_autogen.1 $g2pdatadir/lexicon_autogen.uni
else
    # Done, no need for further processing
    mv $g2pdatadir/lexicon_autogen.bi  $g2pdatadir/lexicon_autogen.1
    exit 0
fi

# If there are still failure cases, remove accent symbols and retry.
if [ $(grep -c failed $g2pdatadir/log.1) -gt 0 ]; then
    # mv $g2pdatadir/lexicon_autogen.1  $g2pdatadir/lexicon_autogen.uni
    MCdictfail=$g2pdatadir/vocab.fail.2
    grep failed $g2pdatadir/log.1 | cut -d ':' -f 1 | \
	cut -d ' ' -f 4 | sed 's/\"//g' > $g2pdatadir/tmp
    local/remove_accents.py $g2pdatadir/tmp $MCdictfail $g2pdatadir/word.map
    
    local/generate_vocab.sh --model_order 1 --pron_variants $pron_variants $MCdictfail $g2p_model_dir $phoneset $g2pdatadir &> $g2pdatadir/log.0

    local/convert_words.py $g2pdatadir/word.map $g2pdatadir/lexicon_autogen.1 $g2pdatadir/lexicon_autogen.0
else
    # Done, no need for accent removal
    cat $g2pdatadir/lexicon_autogen.uni $g2pdatadir/lexicon_autogen.bi | sort > $g2pdatadir/lexicon_autogen.1
    exit 0
fi

# ls $g2pdatadir/lexicon_autogen.*

cat $g2pdatadir/lexicon_autogen.uni $g2pdatadir/lexicon_autogen.bi \
    $g2pdatadir/lexicon_autogen.0 | sort > $g2pdatadir/lexicon_autogen.1
