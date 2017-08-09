## Leda Sari's scripts.

### Get the G2P model.
The directory `./inputs` needs the file `phoneset.txt` and the subdirectories `g2p_reduced` and `g2p_reduced_model`.

### Say where the data is and where Kaldi is.
```
echo /ws/ifp-53_1/hasegawa/lsari2/data/speech_data1 > DATA_ROOT.txt
echo /ws/ifp-53_1/hasegawa/tools/kaldi/kaldi > KALDI_ROOT.txt
```

### Define variables in the settings file read by `run.sh`.

`lang`: The language being transcribed, and the name of the subdirectories
of the data dir `./data` and the output dirs `./exp` and `./$mfccdir`.  
`MCTranscriptdir`: Location of transcription files. Each file corresponds to one long clip. Each line has begin and end times, and `#`-delimited transcriptions.  These files are built by a script `restitch-clips-SomeLanguage.rb` in [`0-mturk`](../0-mturk).  
`pron_var`: Number of pronunciation variants for lexicon generation.  
`lang_subdir`: Location of language data under `DATA_ROOT.txt`.  
`lang_prefix`: Optional prefix of each file in MCTranscriptdir (so 001_001.txt becomes UZB_001_001.txt: see `utt_prefix` in `local/generate_data.py`).  
`sample_rate`: Sample rate, in Hz, of the audio files in `lang_subdir`.  
`stage`: One less than the stage to resume from (to skip early stages when rerunning).  

Examples are in the files `settings_xxx`, for instance [`settings_uzb`](./settings_uzb) for Uzbek.

### Customize.

- For unusual setups for Festival, SRILM, Sequitur G2P, or Python, edit `path.sh`.

- If the data has a different directory structure, edit `DATA_ROOT.txt` and `lang_subdir` to reflect that.

- More customizations are possible in `conf/*`.  (Because `conf/mfcc.conf` is made by `run.sh`, to customize
the former you have to edit the latter.)

- To also run a NN, in `run.sh` uncomment stages 9 and 10, and set the NN's number of layers (default is 3).

### Run it!

`./run.sh settings_uzb`, or `./run.sh settings_rus`, etc.

### Clean up.

To remove generated files, or for a *completely* fresh run when setting `stage=0` in the settings file, remove the directories `exp/$lang` and `data/$lang`.
