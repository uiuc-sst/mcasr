#!/bin/bash
###################################################################
# MCASR run.sh
#
# Train and test a speech recognizer directly from mismatched transcripts.
# Initialized by Mark Hasegawa-Johnson, 6/20/2017,
# based on kaldi/egs/librispeech/s5/run.sh.
# Modified by Leda Sari, 7/19/2017, 7/27/2017.
# Refactored by Camille Goudeseune.
####################################################################

[ $# -ne 1 ] && echo "Usage: $0 settings_file" && exit 1
[ ! -f $1 ]  && echo "$0: missing settings file '$1'." && exit 1

. ./cmd.sh
. ./path.sh
. $1 # Read settings: $data, $lang, $MCTranscriptdir, $lang_subdir, $lang_prefix, $sample_rate, $pron_var, $stage.
[ ! -d $data ] && echo "$0: missing MC data directory $data." && exit 1

set -e

# #################################################################
# # format the data as Kaldi data directories

export LC_ALL=C

if [ $stage -lt 1 ] ; then
  # ( . foo.sh ) shows foo.sh the $variables of run.sh, without letting it change them.
  ( . local/ldc_data_prep.sh )
  echo "Prepared LDC data.\n"

  [ ! -d inputs ] && echo "$0: missing inputs directory 'inputs'" && exit 1
  phoneset=inputs/phoneset.txt # Includes OOV symbol
  g2p_model_dir=inputs/g2p_reduced_model
  g2pdatadir=data/$lang/g2p
  MCdict=$g2pdatadir/vocab.words
  exp=exp/$lang

  # Apply the trained G2P model in $g2p_model_dir, via local/generate_vocab.sh.
  # This script's sequitur command is slow.
  local/apply_g2p.sh --pron_variants $pron_var $MCdict $g2p_model_dir $phoneset $g2pdatadir | sort > $g2pdatadir/lexicon_autogen.1
  echo -e "Generated vocab.\n"

  local/ldc_lang_prep.sh $g2pdatadir data/$lang/local/dict
  echo -e "Prepared LDC language.\n"

  utils/prepare_lang.sh data/$lang/local/dict "<UNK>" data/$lang/local/lang_tmp data/$lang/lang
  echo -e "Prepared language.\n"
fi

nparallel=$[$(nproc)-1] # One fewer than the number of CPU cores.
# Constrain nparallel to at most numlines of $data/segments, for steps/make_mfcc.sh calling utils/split_scp.pl.
nLines=$(wc -l < data/$lang/segments)
[ $nparallel -le $nLines ] || nparallel=$nLines
# todo: like nLines, do the same for the number of speakers (45).
# todo: like nLines, do the same for the number of uttid's.
nj="--nj $nparallel"
datadirs="data/$lang data/$lang/lang"
alignOpt="$nj --cmd $train_cmd $datadirs "

# ++++++++++++ MFCC +++
mfccdir=mfcc
if [ $stage -lt 4 ]; then
  echo -e "--use-energy=false\n--sample-frequency=$sample_rate" > conf/mfcc.conf
  steps/make_mfcc.sh --cmd "$train_cmd" $nj data/$lang $exp/make_mfcc $mfccdir/$lang
  steps/compute_cmvn_stats.sh data/$lang $exp/make_mfcc $mfccdir/$lang
  utils/fix_data_dir.sh data/$lang
fi

# Don't run these stages in parallel,
# because each one uses the previous one's $exp/*_ali alignment dir.

if [ $stage -lt 5 ]; then
  echo -e "\nTraining monophone system."
  steps/train_mono.sh --boost-silence 1.0 $nj --cmd "$train_cmd" \
    $datadirs $exp/mono
  steps/align_si.sh   --boost-silence 1.0 $nj --cmd "$train_cmd" \
    $datadirs $exp/mono $exp/mono_ali

  echo -e "\nTraining triphone system." # Delta + delta-delta, on a subset of (10k?) utterances.
  # Why not $nj ?  train_deltas.sh uses that.
  steps/train_deltas.sh --boost-silence 1.0 --cmd "$train_cmd" \
      2000 10000 $datadirs $exp/mono_ali $exp/tri1
  steps/align_si.sh $alignOpt $exp/tri1 $exp/tri1_ali
fi

if [ $stage -lt 6 ]; then
  echo -e "\nTraining LDA+MLLT system."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
     --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
     $datadirs $exp/tri1_ali $exp/tri2b
  steps/align_si.sh $alignOpt $exp/tri2b $exp/tri2b_ali
fi

if [ $stage -lt 7 ]; then
  echo -e "\nTraining LDA+MLLT+SAT system." # On 15k(?) utterances.
  steps/train_sat.sh --cmd "$train_cmd" \
    2500 15000 \
    $datadirs $exp/tri2b_ali $exp/tri3b
  # Align the entire train_clean_100 subset using the tri3b model.
  steps/align_fmllr.sh $alignOpt $exp/tri3b $exp/tri3b_ali
fi

if [ $stage -lt 8 ]; then
  echo -e "\nTraining bigger LDA+MLLT+SAT system." # On the entire (100 hour?) set?
  steps/train_sat.sh --cmd "$train_cmd" \
    4200 40000 \
    $datadirs $exp/tri3b_ali $exp/tri4b
  # Align using the tri4b model.
  steps/align_fmllr.sh $alignOpt $exp/tri4b $exp/tri4b_ali
fi

# # Optionally, train and test NN model(s).
#
# layers=3 #2
# if [ $stage -lt 9 ]; then
#   echo "Training nnet."
#   local/ldc_run_5a.sh --use_gpu false --num_layers $layers \
# 	$datadirs $exp/tri4b_ali $exp/tri5a_${layers}_nnet
# fi
# if [ $stage -lt 10 ]; then
#   [ ! -f $exp/tri5a_${layers}_nnet/final.mdl ] && echo "Missing nnet file." && exit 1
#   # nj 30 due to tri4b_ali
#   steps/nnet2/align.sh $nj --transform-dir $exp/tri4b_ali $datadirs $exp/tri5a_${layers}_nnet $exp/tri5a_${layers}_nnet_ali
# fi
