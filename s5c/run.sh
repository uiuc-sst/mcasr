#!/bin/bash
###################################################################
# MCASR run.sh
#
# Train and test a speech recognizer directly from mismatched transcripts.
# Initialized by Mark Hasegawa-Johnson, 6/20/2017,
# based on kaldi/egs/librispeech/s5/run.sh. 
# Modified by Leda Sari, 7/19/2017.
####################################################################

###################################################################
# Step 1: Data, paths, and symlinks
# Innovation: I'm creating separate files called
# DATA_ROOT.txt, KALDI_ROOT.txt
# that specify where to find these things.

if [ ! -f DATA_ROOT.txt ]; then
    echo "Create the file DATA_ROOT.txt specifying location"
    echo "of the speech and mc data directories"
    exit
fi
data=`cat DATA_ROOT.txt`
if [ ! -d $data ]; then
    echo "DATA_ROOT.txt said data are stored in ${data}"
    echo "but that location is not a directory"
    exit
fi

. ./cmd.sh
. ./path.sh

# If "steps" and "utils" are not already linked to directories, then
#   create symlinks to the WSJ steps and utils directories
if [ ! -d steps ]; then
    ln -s ${KALDI_ROOT}/egs/wsj/s5/steps .
fi
if [ ! -d utils ]; then
    ln -s ${KALDI_ROOT}/egs/wsj/s5/utils .
fi

# you might not want to do this for interactive shells.
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


# === LM related scripts ===
# We can skip these for now
LM_CORPUS_ROOT=data/$lang/texts
# mkdir -p $LM_CORPUS_ROOT/corpus

# if [ $stage -lt 2 ] ; then
#     export LC_ALL=en_US.UTF-8
#     # Random transcriptions
#     ./local/generate_text.py -N 5 $MCTranscriptdir $LM_CORPUS_ROOT/text
    
#     # awk '{$1=""; print}' $LM_CORPUS_ROOT/text $LM_CORPUS_ROOT/corpus/text.txt
#     while read -r line ; do 
# 	num_unk=$(echo $line | grep -w -o UNK | wc -l); 
# 	if [ $num_unk -lt 12 ]; then echo $line ; fi;   
#     done < $LM_CORPUS_ROOT/text > $LM_CORPUS_ROOT/corpus/text.txt

#     echo "Generate text. Done"
# fi  # end of stage 2

# export LC_ALL=C

# if [ $stage -lt 3 ]; then
#     local/lm/train_lm.sh --normjobs 1 --model_order 2 $LM_CORPUS_ROOT \
# 	data/$lang/local/lm/norm/tmp data/$lang/local/lm/norm/norm_texts data/$lang/local/lm
    
#     local/format_lms.sh --src-dir data/$lang/lang data/$lang/local/lm
#     echo "LM training and formattind: Done"

#     # Create ConstArpaLm format language model for full unigram, bigram LMs
#     utils/build_const_arpa_lm.sh data/$lang/local/lm/lm_unigram.arpa.gz \
# 	data/$lang/lang data/$lang/lang_test_unigram
#     utils/build_const_arpa_lm.sh data/$lang/local/lm/lm_bigram.arpa.gz \
# 	data/$lang/lang data/$lang/lang_test_bigram

# fi  # end of stage 3

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
# exit 0 ; 
# # +++++++++++


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
# # # if you want at this point you can train and test NN model(s)

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
