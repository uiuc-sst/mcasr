# Called from the beginning of ./run.sh.

[ -f KALDI_ROOT.txt ] || { echo "$0: missing file KALDI_ROOT.txt, which says where Kaldi is."; exit 1; }
export KALDI_ROOT=`cat KALDI_ROOT.txt`
[ -d $KALDI_ROOT ] || { echo "$0: missing directory ${KALDI_ROOT}, from KALDI_ROOT.txt."; exit 1; }

[ -f $KALDI_ROOT/tools/config/common_path.sh ] || { echo "$0: missing standard file $KALDI_ROOT/tools/config/common_path.sh"; exit 1; }
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C

# Used by the (optional) LM training and the G2P-related scripts
PYTHON='python2.7'

# ### Paths used by optional parts of run.sh.

# # Festival normalizes text for SRILM.
# FEST_ROOT=tools/festival
# NSW_PATH=${FEST_ROOT}/festival/bin:${FEST_ROOT}/nsw/bin
# export PATH=$PATH:$NSW_PATH

# # SRILM builds a language model.
# SRILM_ROOT=$KALDI_ROOT/tools/srilm
export LIBLBFGS=/home/lsari2/software/kaldi/tools/liblbfgs-1.10
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${LIBLBFGS}/lib/.libs
export SRILM=/home/lsari2/software/kaldi/tools/srilm
SRILM_PATH=$SRILM_ROOT/bin:$SRILM_ROOT/bin/i686-m64
export PATH=$PATH:$SRILM_PATH

# G2P
# sequitur=$KALDI_ROOT/tools/sequitur/g2p.py
sequitur=/home/lsari2/software/kaldi/tools/sequitur/g2p.py
sequitur_path="$(dirname $sequitur)/lib/$PYTHON/site-packages"

# # Directory under which the LM training corpus should be extracted
# LM_CORPUS_ROOT=./lm-corpus
