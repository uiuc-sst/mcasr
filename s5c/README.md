## Leda Sari's scripts.

### Get a G2P model.
Into the directory `./inputs`, put:  
- the file `phoneset.txt`  
- the subdirectory `g2p_reduced`
(with files dict.plain, dict.clean, final.phoneset, final.oldID2newID, lexicon_autogen.1, vocab.plain, vocab.all)  
- the subdirectory `g2p_reduced_model` (with files model-1, model-2, model-3).

### Define variables in the settings file.

Examples of a settings file are `settings_xxx`, e.g. [`settings_uzb`](./settings_uzb) for Uzbek.

**`data`**: Input data (with subdirectories for individual languages).  
**`lang`**: The language being transcribed, and the name of the subdirectories
of the data dir `./data` and the output dirs `./exp` and `./$mfccdir`.  

**`MCTranscriptdir`**: Subdirectory containing transcriptions such as `999_999.txt`. Each file corresponds to one long clip. Each line has begin and end times in microseconds, and `#`-delimited transcriptions, for example:  
`52379999 53627141 baburaad # gaboora ad # gaburaarz`  
These files are built by a script `restitch-clips-SomeLanguage.rb` in [`0-mturk`](../0-mturk).  
**`lang_prefix`**: Optional prefix of each file in `$MCTranscriptdir` (so 001_001.txt becomes UZB_001_001.txt: see `utt_prefix` in `local/generate_data.py`).  
**`scrip_timing_in_samples=true`**: Normally omitted.  Defined only if the time offsets in `$MCTranscriptdir/*` are measured in audio samples (old way) rather than microseconds.  

**`lang_subdir`**: Subtree of `$data` containing `.flac` or `.wav` audio files.  
**`sample_rate`**: Sample rate, in Hz, of the audio files in `$lang_subdir`.  

**`pron_var`**: Number of pronunciation variants for lexicon generation.  
**`stage`**: One less than the stage to resume from (to skip early stages when rerunning).  

### Customize.

- Say where Kaldi is.  In `path.sh`, for example, `export KALDI_ROOT=/ws/ifp-53_1/hasegawa/tools/kaldi/kaldi`.

- For unusual setups for Festival, SRILM, Sequitur G2P, or Python, edit `path.sh`.

- If the data has a different directory structure, reflect that in the settings file's `data` and `lang_subdir` values.

- More customizations are possible in `conf/*`.  (Because `run.sh` makes `conf/mfcc.conf`, to customize
the latter, edit the former.)

- To also run a NN, in `run.sh` uncomment stages 9 and 10, and set the NN's number of layers (default is 3).

### Run it.

`./run.sh settings_uzb`, or `./run.sh settings_rus`, etc.  
This generates the files `exp/$lang/*/ali.*.gz`, `fsts.*.gz`, `trans.*`, logs, and a few others.

### Clean up.

To remove the generated files, or for a *completely* fresh run when setting `stage=0` in the settings file, remove the directories `exp/$lang` and `data/$lang`.
