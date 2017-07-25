## Leda Sari's scripts.

### Copy the scripts and the input files.
```
setupdir='../s5c'
expdir='.'
cp -r $setupdir/{conf,cmd.sh,path.sh,local,steps,utils,run.sh} $expdir
```

Also copy the G2P model:
`cp -r $setupdir/inputs $expdir`

### Say where the data is and where Kaldi is.
```
echo /ws/ifp-53_1/hasegawa/lsari2/data/speech_data1 > DATA_ROOT.txt
echo /ws/ifp-53_1/hasegawa/tools/kaldi/kaldi > KALDI_ROOT.txt
```

### Set some variables in `run.sh`.

`lang`: Language being transcribed.  
`MCTranscriptdir`: Location of transcription files. Each file corresponds to one long clip. Each line has begin and end times, and `#`-delimited transcriptions.  These files are built by a script `restitch-clips-SomeLanguage.rb` in [`0-mturk`](../0-mturk).  
`pron_var`: Number of pronunciation variants for lexicon generation.  
`lang_subdir`: Location of language data under `DATA_ROOT.txt`.  
`lang_prefix`: Optional prefix of each file in MCTranscriptdir (to convert UZB_001_001.txt to 001_001.txt).  
`stage`: One less than the stage to resume from (to skip early stages).  


Example:
```
lang=uzbek
MCTranscriptdir=leda_uzbek
pron_var=5
lang_subdir=Uzbek/LDC2016E66/UZB_20160711
lang_prefix=UZB
stage=0 # start
```

### Customize.

- For unusual setups for Festival, SRILM, Sequitur G2P, or Python, edit `path.sh`.

- If the data has a different directory structure, edit `DATA_ROOT.txt` and `lang_subdir` to reflect that.

- If the data's audio sample rate isn't 44100 Hz,  
set it in `conf/mfcc.conf`'s `--sample-frequency`  
and also in `local/ldc_data_prep.sh`'s `fs`.

- To also run a NN, in `run.sh` uncomment stages 9 and 10, and set the NN's number of layers (default is 3).

### Run it!

`./run.sh`
