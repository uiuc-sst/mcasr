# Called from the beginning of ./run.sh.

if [ ! -e KALDI_ROOT.txt ]; then
    echo "Missing file KALDI_ROOT.txt, which says where Kaldi is."
    exit 1
fi
export KALDI_ROOT=`cat KALDI_ROOT.txt`
if [ ! -d $KALDI_ROOT ]; then
    echo "The location ${KALDI_ROOT}, from KALDI_ROOT.txt, is not a directory or is unreadable."
    exit 1
fi

export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C

# Used by the (optional) LM training and the G2P-related scripts
PYTHON='python2.7'

# ### Paths used by optional parts of run.sh.

# # Festival is only for optional text normalization (for LM-training).
# FEST_ROOT=tools/festival
# NSW_PATH=${FEST_ROOT}/festival/bin:${FEST_ROOT}/nsw/bin
# export PATH=$PATH:$NSW_PATH

# # SRILM is for LM model building
# SRILM_ROOT=$KALDI_ROOT/tools/srilm
# SRILM_PATH=$SRILM_ROOT/bin:$SRILM_ROOT/bin/i686-m64
# export PATH=$PATH:$SRILM_PATH

# Sequitur G2P
# sequitur=$KALDI_ROOT/tools/sequitur/g2p.py
sequitur=/home/lsari2/software/kaldi/tools/sequitur/g2p.py
sequitur_path="$(dirname $sequitur)/lib/$PYTHON/site-packages"

# # Directory under which the LM training corpus should be extracted
# LM_CORPUS_ROOT=./lm-corpus

# SRILM
export LIBLBFGS=/home/lsari2/software/kaldi/tools/liblbfgs-1.10
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${LIBLBFGS}/lib/.libs
export SRILM=/home/lsari2/software/kaldi/tools/srilm
export PATH=${PATH}:${SRILM}/bin:${SRILM}/bin/i686-m64
