#!/bin/bash

# On stdin read a nonsense-English pronlex (aka MCdict),
# e.g. /ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromWenda/dict_grapheme.txt.
# Keep its words; discard its pronunciations.
# Via g2p.sh, create lexicon_autogen.1, for our caller apply_g2p.sh to modify.

export LC_ALL=C

# Default values for parse_options.sh.
dd=data/Uyghur/local/g2p
model_order=2
pron_variants=5

. ./path.sh || exit 1
. utils/parse_options.sh || exit 1

[ "$#" -ne 3 ] && >&2 echo "Usage: $0 G2P_model_dir phone_set G2P_data_dir < MC_vocab/dict &> logfile" && exit 1
# e.g., inputs/g2p_reduced_model inputs/phoneset.txt data/myLanguage/g2p
 
g2pmodeldir=$1
phoneset=$2
dd=$3 # Data dir.

[ ! -d $g2pmodeldir ] && >&2 echo "$0: missing G2P model dir $g2pmodeldir." && exit 1
[ ! -f $phoneset    ] && >&2 echo "$0: missing phone set $phoneset." && exit 1

>&2 echo "$0: model order and number of pronunciation variants for G2P application are: $model_order $pron_variants"

# Copy the g2p model and the phone set to the data dir.
g2pmodel=$g2pmodeldir/model-$model_order
[ ! -f $g2pmodel ] && >&2 echo "$0: missing G2P model $g2pmodel." && exit 1
mkdir -p $dd
cp $g2pmodel $phoneset $dd

# Back up any vocab.plain from a previous run of this script (called by local/apply_g2p.sh).
[ -f $dd/vocab.plain ] && mv $dd/vocab.plain $dd/vocab.plain.0

# Get words from the first column.
# Keep only words that start with letters.
# Strip punctuation.
cut -d ' ' -f1 | egrep -v '^[^a-z]' | tr -d '[:punct:]' | sort -u > $dd/vocab.plain

# The G2P must be already trained.
local/g2p.sh $dd/vocab.plain $dd $dd/lexicon_autogen.1 $model_order $pron_variants 2>&1 $dd/log.$model_order
