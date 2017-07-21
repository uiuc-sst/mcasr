
1) Copy scripts and the input files
setupdir='../s5c'
expdir='.'

cp -r $setupdir/{conf,cmd.sh,path.sh,local,steps,utils,run.sh} $expdir

Also copy the G2P model
cp -r $setupdir/inputs $expdir


2) Create DATA_ROOT.txt  KALDI_ROOT.txt
DATA_ROOT.txt
e.g. /ws/ifp-53_1/hasegawa/lsari2/data/speech_data1

KALDI_ROOT.txt
e.g. /ws/ifp-53_1/hasegawa/tools/kaldi/kaldi

3) Set the following variables in the run.sh script
# Name of the language
lang=uzbek
# Mismatched transcript dir, each file correspons to one long clip
  and each line has begin-end time information and transcriptions 
  separated by '#'. 
MCTranscriptdir=
# Number of pronunciation variants for lexicon generation
pron_var=
# Where the language data is located under DATA_ROOT.txt
lang_subdir=
# Prefix of the language in data directory (can be optional)
# to convert from 001_001.txt to UZB_001_001.txt
lang_prefix=
# Stage to start the script, if setup is partially done
# start from a different stage (stage number that you want to run minus 1)
stage=

Example:
lang=uzbek
MCTranscriptdir=leda_uzbek
pron_var=5
lang_subdir=Uzbek/LDC2016E66/UZB_20160711
lang_prefix=UZB
stage=0 # start

4) If you want to run a neural network setup, uncomment stage 7 and 8 
and set the number of layers, default is 3

5) Run run.sh

 

Possible issues:
- Depending on your environment, you may want to modify 'path.sh'

- If data directory structure differs, DATA_ROOT.txt and lang_subdir may need modification

- If sampling frequency of the data set is different, 
  modify --sample-frequency in conf/mfcc.conf
  and also fs in local/ldc_data_prep.sh
