## Mismatched Crowdsourcing Automatic Speech Recognition
### Train an ASR directly from mismatched transcripts, based on [kaldi/egs/librispeech](https://github.com/kaldi-asr/kaldi/tree/master/egs/librispeech).

<!-- https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet -->

Mismatched transcripts are produced by people writing down what they
hear in a language L2, as if it were nonsense syllables in their own
language, English.

This has two sources of variability, which we solve separately:

- To solve **English orthography**, we align a transcript to its audio with a nonsense-English ASR.

- To solve **L2-to-English misperception**, we generate candidate L2 word transcriptions,
use them to train an L2 recognizer, and then align them to the audio.
 
We need these software components:

### 0. Submit audio to Mechanical Turk.

[Instructions and scripts.](./0-mturk/)

### 1. English nonsense dictionary

Make a pronunciation lexicon of English nonsense words, which Kaldi calls `lexiconp.txt`.
(a) Its vocabulary is the space-delimited words in Turker transcripts.
(b) To find each word's pronunciation, we're experimenting with two methods.  First, we tried finding each word's pronunciations with www.isle.illinois.edu/sst/data/g2ps/English/English_ref_orthography_dict.html, but we discovered that this transformation yields too many different candidate pronunciations for each nonsense word.  Second, we are using www.isle.illinois.edu/sst/data/g2ps/English/ISLEdict.html and https://github.com/sequitur-g2p/sequitur-g2p to train an English g2p, and then ask sequitur to print out the top-10 most likely pronunciations of each nonsense word, together with their probabilities, in  `lexiconp.txt`.

Scripts are in the subfolder [1-nonsenseDict](./1-nonsenseDict).
The script [1-nonsenseDict/split-words.rb](1-nonsenseDict/split-words.rb) will also preprocess turker transcripts (like <https://github.com/uiuc-sst/PTgen/blob/master/steps/preprocess_turker_transcripts.pl>).

### 2. English ASR and forced alignment

Using the lexicons from part 1, plus https://github.com/kaldi-asr/kaldi/ we train an English ASR.  Using the ASR, we force-align the Turker transcripts to the audio clips.  This forced alignment process chooses, from the ten candidate pronunciations of each nonsense word, the one that seems to best match the audio.

### 3. From English phones to L2 phones

Now that we have figured out which English phones were being represented by the nonsense-word transcriptions, we then need to somehow jump from English to L2.  One way to do this is to use https://github.com/uiuc-sst/PTgen to compute candidate L2 phone strings that might match each English phone string.

### 4. From L2 phones to L2 words

The final goal is L2 words.  One way to get L2 words is to create an L2 pronunciation lexicon, then use fstviterbibeamsearch to find the L2 word string that best matches each L2 phone string. 

In order to use this method, we need to estimate an L2 pronunciation dictionary.  Inputs: an L2 word list, and an L2 G2P.  (a) Data provided by LORELEI include at least 120k words of monolingual text, so one method to generate a word list is to find all unique tokens in the monolingual text.  (b) unweighted unigram G2Ps exist for ~100 languages at www.isle.illinois.edu/sst/data/g2ps/

### 5. Other options

The goal is: given L2 audio and English nonsense words, figure out which L2 words were spoken.  

(a) https://github.com/uiuc-sst/PTgen already achieves this goal somewhat directly. (b) Steps #1-4 achieve this goal somewhat less directly, but we are hoping that it might work better, because it uses English-nonsense-word ASR to resolve ambiguities in English orthography first, before tackling ambiguities in cross-language speech perception, (c) after we try this, we can try other methods.  
