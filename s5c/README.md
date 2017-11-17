## Leda Sari's scripts.

### Get G2P models.
Into the directory `./inputs`, put:  
- the file `phoneset.txt`  
- the subdirectory `g2p_reduced`
(with files dict.plain, dict.clean, final.phoneset, final.oldID2newID, lexicon_autogen.1, vocab.plain, vocab.all;
vocab.* came from an English dictionary)  
- the subdirectory `g2p_reduced_model` (trained G2P models, as files model-1, model-2, model-3).

These files come from Leda Sari's scripts, which train several G2P models from
a pronunciation dictionary and a manually extended English dictionary.
These need to be rerun only when the dictionary or `phoneset.txt` is changed.

### Get recordings of speech.
These have the same attributes such as format (.flac or .wav) and sampling rate.
Their names are arbitrary.
They are in a single directory subtree (not necessarily one flat directory), which the next step will call `$data/$lang_subdir`.  This subtree may contain other files (e.g., an [LDC](www.ldc.upenn.edu) corpus that has both audio files and annotation files).

### Get transcriptions of these speech recordings.
Each audio file needs a corresponding transcription file,
with the same name, except that it ends in `.txt`, and that it may omit a prefix common to all the audio files (`$lang_prefix` below).
For example, `UZB_449_004.wav` might have `449_004.txt`.  
Each transcription file has a set of lines.  Each line has a begin time in μs, an end time in μs, and `#`-delimited transcriptions, for example:  
`52379999 53627141 baburaad # gaboora ad # gaburaarz`.  Lines are sorted by begin time.  
The transcription files are in a single directory, which the next step will call `$MCTranscriptdir`.  
If the transcriptions were crowdsourced, these transcription files (one per second-long audio clip) can be built by a script `restitch-clips-SomeLanguage.rb` in [`0-mturk`](../0-mturk).  
If the transcriptions came from a native speaker, each transcription file (one per original audio file) is then just a single line: begin time, end time, and the transcription itself.  These files can be built by, e.g., [`0-mturk/prepare-NI.rb`](../0-mturk/prepare-NI.rb).  

### Define variables in the settings file.

Examples of a settings file are `settings_xxx`, e.g. [`settings_uzb`](./settings_uzb) for Uzbek.

**`data`**: Directory containing input data (with subdirectories for individual languages).  
**`lang`**: The language being transcribed, and the name of the subdirectories
of the input dir `./data` and the output dirs `./exp` and `./$mfccdir`.  

**`lang_subdir`**: Subtree of `$data` containing speech recordings.  To use all of `$data`, just make this `.`.  
**`sample_rate`**: Sample rate of these recordings, in Hz.  

**`MCTranscriptdir`**: Subdirectory containing text transcriptions such as `449_004.txt`.     
**`lang_prefix`**: Common prefix of files in `$data/$lang_subdir`, which is omitted by `$MCTranscriptdir/*.txt` (so `UZB_449_004.wav` corresponds to `449_004.txt`: see `utt_prefix` in [`local/generate_data.py`](local/generate_data.py)). Optional; defaults to nothing.  
**`scrip_timing_in_samples=true`**: Usually omitted.  Defined only if the time offsets in `$MCTranscriptdir/*` are measured in audio samples (old way) rather than microseconds.  

**`pron_var`**: Number of pronunciation variants for lexicon generation.  
**`stage`**: One less than the stage to resume from (to skip early stages when rerunning).  

### Customize.

- Say where Kaldi is.  In `path.sh`, for example, `export KALDI_ROOT=/ws/ifp-53_1/hasegawa/tools/kaldi/kaldi`.

- For unusual setups for Festival, SRILM, Sequitur G2P, or Python, edit `path.sh`.

- If the data has a different directory structure, reflect that in the settings file's `$data` and `$lang_subdir`.

- More customizations are possible in `conf/*`.  (Because `run.sh` makes `conf/mfcc.conf`, to customize
the latter, edit the former.)

- To also run a NN, in `run.sh` uncomment stages 9 and 10, and set the NN's number of layers (default is 3).

### Run it.

`./run.sh settings_uzb`, or `./run.sh settings_rus`, etc.  
This generates the files `exp/$lang/*/ali.*.gz`, `fsts.*.gz`, `trans.*`, log files, and a few other files.

### Clean up.

To remove the generated files, or for a *completely* fresh run when setting `stage=0` in the settings file, remove the directories `exp/$lang` and `data/$lang` (but keep `data/$lang/g2p/phoneset.txt`).
