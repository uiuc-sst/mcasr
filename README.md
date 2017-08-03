## [Mismatched Crowdsourcing](https://github.com/uiuc-sst/PTgen) [Automatic Speech Recognition](https://en.wikipedia.org/wiki/Speech_recognition)
### Train an ASR directly from mismatched transcripts, based on [kaldi/egs/librispeech](https://github.com/kaldi-asr/kaldi/tree/master/egs/librispeech).

<!-- https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet -->

Mismatched transcripts are produced by people writing down what they
hear in a language L2, as if it were nonsense syllables in their own
language, English.

This has two sources of variability, which we solve separately:

- To solve **English orthography**, we align a transcript to its audio with a nonsense-English ASR.

- To solve **L2-to-English misperception**, we generate candidate L2 word transcriptions,
use them to train an L2 recognizer, and then align them to the audio.
 
We use these software components:

### 0. Transcribe audio via Mechanical Turk.

[Instructions and scripts.](./0-mturk/)

### 1. English nonsense dictionary

Make a pronunciation lexicon of English nonsense words, which Kaldi calls `lexiconp.txt`.
(a) Its vocabulary is the space-delimited words in Turker transcripts.
(b) Find each word's pronunciation.  Because the transformation www.isle.illinois.edu/sst/data/g2ps/English/English_ref_orthography_dict.html yields too many candidate pronunciations for each nonsense word, use [ISLEdict](www.isle.illinois.edu/sst/data/g2ps/English/ISLEdict.html) and [Sequitur](https://github.com/sequitur-g2p/sequitur-g2p) to train an English g2p, and then ask Sequitur to report the ten most likely pronunciations of each nonsense word, together with their probabilities, in  `lexiconp.txt`.

Scripts are in the subfolder [1-nonsenseDict](./1-nonsenseDict).
The script [split-words.rb](1-nonsenseDict/split-words.rb) will also preprocess turker transcripts (like <https://github.com/uiuc-sst/PTgen/blob/master/steps/preprocess_turker_transcripts.pl>).

### 2. English ASR and forced alignment

Use the lexicons from part 1 to train a [Kaldi](https://github.com/kaldi-asr/kaldi/) English ASR.  This force-aligns Turker transcripts to audio clips by choosing, for each nonsense word's ten candidate pronunciations, the one that best matches the audio.

### 3. From English phones to L2 phones

Now that we know which English phones were represented by the nonsense-word transcriptions, we jump from English to L2.  One way to do this is to use [PTgen](https://github.com/uiuc-sst/PTgen) to compute candidate L2 phone strings that might match each English phone string.

### 4. From L2 phones to L2 words

The final goal is L2 words.  One way to get this is to create an L2 pronunciation lexicon, and then use fstviterbibeamsearch to find the L2 word string that best matches each L2 phone string.  For this we must estimate an L2 pronunciation dictionary, from an L2 word list and an L2 G2P.
The word list can come from the unique tokens in the monolingual text; LORELEI provides at least 120k such words.
The G2P can come from our [unweighted unigram G2Ps](www.isle.illinois.edu/sst/data/g2ps/) for a hundred languages.

### 5. Other methods

The goal is: given L2 audio and matching English nonsense words, figure out which L2 words were spoken.  

- [PTgen](https://github.com/uiuc-sst/PTgen) already does this.

- Steps 1-4 do this less directly, but performance may improve, because English-nonsense-word ASR first resolves ambiguities in English orthography, before tackling ambiguities in cross-language speech perception.

- After we try this, we can try other methods. 
