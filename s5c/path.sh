if [ ! -e KALDI_ROOT.txt ]; then
    echo "Please create a file KALDI_ROOT.txt specifying where to find kaldi"
    exit
fi
export KALDI_ROOT=`cat KALDI_ROOT.txt`
if [ ! -d $KALDI_ROOT ]; then
    echo "KALDI_ROOT.txt said kaldi is in ${KALDI_ROOT}, but that's not a directory"
    exit
fi

export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C

# we use this both in the (optional) LM training and the G2P-related scripts
PYTHON='python2.7'

# ### Below are the paths used by the optional parts of the recipe

# # We only need the Festival stuff below for the optional text normalization(for LM-training) step
# FEST_ROOT=tools/festival
# NSW_PATH=${FEST_ROOT}/festival/bin:${FEST_ROOT}/nsw/bin
# export PATH=$PATH:$NSW_PATH

# # SRILM is needed for LM model building
# SRILM_ROOT=$KALDI_ROOT/tools/srilm
# SRILM_PATH=$SRILM_ROOT/bin:$SRILM_ROOT/bin/i686-m64
# export PATH=$PATH:$SRILM_PATH

# # Sequitur G2P executable
# sequitur=$KALDI_ROOT/tools/sequitur/g2p.py
# sequitur_path="$(dirname $sequitur)/lib/$PYTHON/site-packages"

# # Directory under which the LM training corpus should be extracted
# LM_CORPUS_ROOT=./lm-corpus

# Sequitur G2P executable
sequitur=/home/lsari2/software/kaldi/tools/sequitur/g2p.py
# $KALDI_ROOT/tools/sequitur/g2p.py
sequitur_path="$(dirname $sequitur)/lib/$PYTHON/site-packages"

# SRILM
export LIBLBFGS=/home/lsari2/software/kaldi/tools/liblbfgs-1.10
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${LIBLBFGS}/lib/.libs
export SRILM=/home/lsari2/software/kaldi/tools/srilm
export PATH=${PATH}:${SRILM}/bin:${SRILM}/bin/i686-m64
