#!/bin/bash
###################################################################
# MCASR run.sh
#
# Train and test a speech recognizer directly from mismatched transcripts.
# Initialized by Mark Hasegawa-Johnson, 6/20/2017,
# based on kaldi/egs/librispeech/s5/run.sh. 
# Modified by Leda Sari, 7/19/2017.
####################################################################

if [ ! -f DATA_ROOT.txt ]; then
    echo "Missing file DATA_ROOT.txt, which specifies the MC data directory."
    exit 1
fi
data=`cat DATA_ROOT.txt`
if [ ! -d $data ]; then
    echo "The location ${data}, from DATA_ROOT.txt, is not a directory."
    exit 1
fi

. ./cmd.sh
. ./path.sh

# Directories ./steps and ./utils are copies instead of symlinks,
# because Leda needed changes in them.

set -e

# #################################################################
# # format the data as Kaldi data directories

lang=Uzbek

MCTranscriptdir=/ws/ifp-53_1/hasegawa/lsari2/data/mcasr/fromCamille/leda-uzbek/
pron_var=5
lang_subdir=Uzbek/LDC2016E66/UZB_20160711
lang_prefix=UZB
stage=0

export LC_ALL=C

# if [ ! -f data/$lang/lang/L.fst ] ; then
if [ $stage -lt 1 ] ; then

local/ldc_data_prep.sh $lang_subdir $MCTranscriptdir data/$lang $lang_prefix
echo "+++ Data prep done"

g2p_model_dir=inputs/g2p_reduced_model
phoneset=inputs/phoneset.txt # Includes OOV symbol
g2pdatadir=data/$lang/g2p
MCdict=$g2pdatadir/vocab.words 

# Apply G2P (Assuming that we have already trained a G2P model)
local/generate_vocab.sh --model_order 2 --pron_variants $pron_var $MCdict $g2p_model_dir $phoneset $g2pdatadir 
echo "Generate vocab: Done"

bash local/ldc_lang_prep.sh $g2pdatadir data/$lang/local/dict
echo 'lang prep: Done'


utils/prepare_lang.sh data/$lang/local/dict \
  "<UNK>" data/$lang/local/lang_tmp data/$lang/lang
echo "prepare_lang: Done"
fi

export LC_ALL=C

# ++++++++++++ MFCC +++
mfccdir=mfcc
if [ $stage -lt 4 ]; then 
# # for part in LDC2016E66 LDC2016E119 LDC2016E111 ; do
for part in $lang; do
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 8 data/$part exp/$part/make_mfcc $mfccdir/$part
  steps/compute_cmvn_stats.sh data/$part exp/$part/make_mfcc $mfccdir/$part
  utils/fix_data_dir.sh data/$part
done
fi

if [ $stage -lt 5 ]; then
# #################################################################
# train a monophone system
steps/train_mono.sh --boost-silence 1.0 --nj 8 --cmd "$train_cmd" \
  data/$lang data/$lang/lang exp/$lang/mono

steps/align_si.sh --boost-silence 1.0 --nj 10 --cmd "$train_cmd" \
  data/$lang data/$lang/lang exp/$lang/mono exp/$lang/mono_ali

# ####################################################################
# # train a first delta + delta-delta triphone system on a subset of 5000 utterances
steps/train_deltas.sh --boost-silence 1.0 --cmd "$train_cmd" \
    2000 10000 data/$lang data/$lang/lang exp/$lang/mono_ali exp/$lang/tri1

steps/align_si.sh --nj 10 --cmd "$train_cmd" \
  data/$lang data/$lang/lang exp/$lang/tri1 exp/$lang/tri1_ali

# ##########
fi 

if [ $stage -lt 6 ]; then 
# ##########################################################################
echo " === Start training LDA+MLLT system ==="
# # train an LDA+MLLT system.
steps/train_lda_mllt.sh --cmd "$train_cmd" \
   --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
   data/$lang data/$lang/lang exp/$lang/tri1_ali exp/$lang/tri2b

# # decode using the LDA+MLLT model
  # utils/mkgraph.sh data/$lang/lang_test_bigram \
  #   exp/$lang/tri2b exp/$lang/tri2b/graph_bigram

# (
#   utils/mkgraph.sh data/lang_nosp_test_tgsmall \
#     exp/tri2b exp/tri2b/graph_nosp_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode.sh --nj 20 --cmd "$decode_cmd" exp/tri2b/graph_nosp_tgsmall \
#       data/$test exp/tri2b/decode_nosp_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
#       data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
#       data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
#   done
# )&

# steps/align_si.sh  --nj 10 --cmd "$train_cmd" --use-graphs true \
#   data/$lang data/$lang/lang exp/$lang/tri2b exp/$lang/tri2b_ali
steps/align_si.sh  --nj 10 --cmd "$train_cmd" \
  data/$lang data/$lang/lang exp/$lang/tri2b exp/$lang/tri2b_ali

# ##################################################################
# # Train tri3b, which is LDA+MLLT+SAT on 10k utts
echo " === Start training LDA+MLLT+SAT system ==="
steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
  data/$lang data/$lang/lang exp/$lang/tri2b_ali exp/$lang/tri3b

# # align the entire train_clean_100 subset using the tri3b model
steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" \
  data/$lang data/$lang/lang \
  exp/$lang/tri3b exp/$lang/tri3b_ali

# ######################################################################
echo " === Another LDA+MLLT+SAT system ==="
# # train another LDA+MLLT+SAT system on the entire 100 hour subset
steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 \
  data/$lang data/$lang/lang \
  exp/$lang/tri3b_ali exp/$lang/tri4b

# align using the tri4b model
steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/$lang data/$lang/lang exp/$lang/tri4b exp/$lang/tri4b_ali

# ##################
fi 

# #########################################################################
# # ++++++ NNET ++++++
# # # optionally, train and test NN model(s)

# layers=3 #2
# if [ $stage -lt 7 ]; then 
# echo " === Start training nnet === "
#     local/ldc_run_5a.sh --use_gpu false --num_layers $layers \
# 	data/$lang data/$lang/lang exp/$lang/tri4b_ali exp/$lang/tri5a_${layers}_nnet
# fi
# if [ $stage -lt 8 ]; then 
#     [ -f exp/$lang/tri5a_${layers}_nnet/final.mdl ] || { echo 'No nnet file' ; exit 1 ; } ;
#     # nj 30 due to tri4b_ali
#     steps/nnet2/align.sh --nj 30 --transform-dir exp/$lang/tri4b_ali data/$lang data/$lang/lang exp/$lang/tri5a_${layers}_nnet exp/$lang/tri5a_${layers}_nnet_ali
# fi
