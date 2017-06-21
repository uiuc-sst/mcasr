#!/bin/bash
###################################################################
# MCASR run.sh
#
# Train and test a speech recognizer directly from mismatched transcripts.
# Initialized by Mark Hasegawa-Johnson, 6/20/2017,
# based on kaldi/egs/librispeech/s5/run.sh.  Most of what you see here
# is just copied from the Librispeech recipe, little has yet been changed.
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

#################################################################
# format the data as Kaldi data directories
for part in `ls $data`; do
  # use underscore-separated names in data directories.
  local/data_prep.sh $data/$part data/$(echo $part | sed s/-/_/g)
done

## Optional text corpus normalization and LM training
## These scripts are here primarily as a documentation of the process that has been
## used to build the LM. Most users of this recipe will NOT need/want to run
## this step. The pre-built language models and the pronunciation lexicon, as
## well as some intermediate data(e.g. the normalized text used for LM training),
## are available for download at http://www.openslr.org/11/
#local/lm/train_lm.sh $LM_CORPUS_ROOT \
#  data/local/lm/norm/tmp data/local/lm/norm/norm_texts data/local/lm

## Optional G2P training scripts.
## As the LM training scripts above, this script is intended primarily to
## document our G2P model creation process
#local/g2p/train_g2p.sh data/local/dict/cmudict data/local/lm

# when "--stage 3" option is used below we skip the G2P steps, and use the
# lexicon we have already downloaded from openslr.org/11/
local/prepare_dict.sh --stage 3 --nj 30 --cmd "$train_cmd" \
   data/local/lm data/local/lm data/local/dict_nosp

utils/prepare_lang.sh data/local/dict_nosp \
  "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

local/format_lms.sh --src-dir data/lang_nosp data/local/lm

# Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
  data/lang_nosp data/lang_nosp_test_tglarge
utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz \
  data/lang_nosp data/lang_nosp_test_fglarge

mfccdir=mfcc
# spread the mfccs over various machines, as this data-set is quite large.
if [[  $(hostname -f) ==  *.clsp.jhu.edu ]]; then
  mfcc=$(basename mfccdir) # in case was absolute pathname (unlikely), get basename.
  utils/create_split_dir.pl /export/b{02,11,12,13}/$USER/kaldi-data/egs/librispeech/s5/$mfcc/storage \
    $mfccdir/storage
fi


for part in dev_clean test_clean dev_other test_other train_clean_100; do
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/$part exp/make_mfcc/$part $mfccdir
  steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
done

# Make some small data subsets for early system-build stages.  Note, there are 29k
# utterances in the train_clean_100 directory which has 100 hours of data.
# For the monophone stages we select the shortest utterances, which should make it
# easier to align the data from a flat start.

utils/subset_data_dir.sh --shortest data/train_clean_100 2000 data/train_2kshort
utils/subset_data_dir.sh data/train_clean_100 5000 data/train_5k
utils/subset_data_dir.sh data/train_clean_100 10000 data/train_10k

#################################################################
# train a monophone system
steps/train_mono.sh --boost-silence 1.25 --nj 20 --cmd "$train_cmd" \
  data/train_2kshort data/lang_nosp exp/mono

# decode using the monophone model
(
  utils/mkgraph.sh --mono data/lang_nosp_test_tgsmall \
    exp/mono exp/mono/graph_nosp_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode.sh --nj 20 --cmd "$decode_cmd" exp/mono/graph_nosp_tgsmall \
      data/$test exp/mono/decode_nosp_tgsmall_$test
  done
)&

steps/align_si.sh --boost-silence 1.25 --nj 10 --cmd "$train_cmd" \
  data/train_5k data/lang_nosp exp/mono exp/mono_ali_5k

####################################################################
# train a first delta + delta-delta triphone system on a subset of 5000 utterances
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train_5k data/lang_nosp exp/mono_ali_5k exp/tri1

# decode using the tri1 model
(
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri1 exp/tri1/graph_nosp_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode.sh --nj 20 --cmd "$decode_cmd" exp/tri1/graph_nosp_tgsmall \
      data/$test exp/tri1/decode_nosp_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      data/$test exp/tri1/decode_nosp_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      data/$test exp/tri1/decode_nosp_{tgsmall,tglarge}_$test
  done
)&

steps/align_si.sh --nj 10 --cmd "$train_cmd" \
  data/train_10k data/lang_nosp exp/tri1 exp/tri1_ali_10k

##########################################################################
# train an LDA+MLLT system.
steps/train_lda_mllt.sh --cmd "$train_cmd" \
   --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
   data/train_10k data/lang_nosp exp/tri1_ali_10k exp/tri2b

# decode using the LDA+MLLT model
(
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri2b exp/tri2b/graph_nosp_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode.sh --nj 20 --cmd "$decode_cmd" exp/tri2b/graph_nosp_tgsmall \
      data/$test exp/tri2b/decode_nosp_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
  done
)&

# Align a 10k utts subset using the tri2b model
steps/align_si.sh  --nj 10 --cmd "$train_cmd" --use-graphs true \
  data/train_10k data/lang_nosp exp/tri2b exp/tri2b_ali_10k

##################################################################
# Train tri3b, which is LDA+MLLT+SAT on 10k utts
steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
  data/train_10k data/lang_nosp exp/tri2b_ali_10k exp/tri3b

# decode using the tri3b model
(
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri3b exp/tri3b/graph_nosp_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
      exp/tri3b/graph_nosp_tgsmall data/$test \
      exp/tri3b/decode_nosp_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
  done
)&

# align the entire train_clean_100 subset using the tri3b model
steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" \
  data/train_clean_100 data/lang_nosp \
  exp/tri3b exp/tri3b_ali_clean_100

######################################################################
# train another LDA+MLLT+SAT system on the entire 100 hour subset
steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 \
  data/train_clean_100 data/lang_nosp \
  exp/tri3b_ali_clean_100 exp/tri4b

# decode using the tri4b model
(
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri4b exp/tri4b/graph_nosp_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
      exp/tri4b/graph_nosp_tgsmall data/$test \
      exp/tri4b/decode_nosp_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      data/$test exp/tri4b/decode_nosp_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      data/$test exp/tri4b/decode_nosp_{tgsmall,tglarge}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,fglarge} \
      data/$test exp/tri4b/decode_nosp_{tgsmall,fglarge}_$test
  done
)&

##################################################################
# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
steps/get_prons.sh --cmd "$train_cmd" \
  data/train_clean_100 data/lang_nosp exp/tri4b
utils/dict_dir_add_pronprobs.sh --max-normalize true \
  data/local/dict_nosp \
  exp/tri4b/pron_counts_nowb.txt exp/tri4b/sil_counts_nowb.txt \
  exp/tri4b/pron_bigram_counts_nowb.txt data/local/dict

utils/prepare_lang.sh data/local/dict \
  "<UNK>" data/local/lang_tmp data/lang
local/format_lms.sh --src-dir data/lang data/local/lm

utils/build_const_arpa_lm.sh \
  data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge
utils/build_const_arpa_lm.sh \
  data/local/lm/lm_fglarge.arpa.gz data/lang data/lang_test_fglarge

# decode using the tri4b model with pronunciation and silence probabilities
(
  utils/mkgraph.sh \
    data/lang_test_tgsmall exp/tri4b exp/tri4b/graph_tgsmall
  for test in test_clean test_other dev_clean dev_other; do
    steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
      exp/tri4b/graph_tgsmall data/$test \
      exp/tri4b/decode_tgsmall_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      data/$test exp/tri4b/decode_{tgsmall,tgmed}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/$test exp/tri4b/decode_{tgsmall,tglarge}_$test
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
      data/$test exp/tri4b/decode_{tgsmall,fglarge}_$test
  done
)&

# align train_clean_100 using the tri4b model
steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train_clean_100 data/lang exp/tri4b exp/tri4b_ali_clean_100

########################################################################
# if you want at this point you can train and test NN model(s) on the 100 hour
# subset
local/nnet2/run_5a_clean_100.sh


# Wait for decodings in the background
wait
