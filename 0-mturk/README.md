# How to create tasks for [Amazon Mechanical Turk](https://www.mturk.com/mturk/welcome)

### [Login](https://requester.mturk.com/begin_signin).
- Click on Create.
- Using an existing project, at right click on Copy.
- Edit the copy as needed.

To adjust how many turkers transcribe each HIT:

- Edit Project, Setting up your HIT, Number of assignments per HIT: type in a number between 5 and 10.

Bigger numbers reduce noise, but obviously cost proportionally more.

### Get a collection of recordings of speech.
In .wav format, mono, preferably with a uniform sampling rate (22050 Hz).

- If they're in .flac format, first convert them to .wav, to avoid a bug in sox:

`for f in *.flac; do sox "$f" "$( basename ${f%.flac}.wav )"; done;`
    
### Split each .wav into 1.25 second clips, in .mp3 and .ogg format.

- [`./split.rb`](./split.rb)

This reads the .wav files and writes `/tmp/turkAudio.tar`.
It runs at about 3 minutes per hour of input audio.

### On ifp-serv-03:
- `cd /workspace/speech_web/mc/`
- `mkdir myTest; cd myTest`
- Into here, copy `turkAudio.tar` that was made by `split.rb`.
- `tar xf turkAudio.tar`

### Create a "Batch file."
[`./make-csv.rb myTest > foo.csv`](./make-csv.rb)

### Submit the batch file `foo.csv` to Mechanical Turk's *Publish Batch.*
If needed, first split it into quarters (each starting with the
original's first line), and submit it only one quarter at a time.
That yields intermediate results more quickly, because each quarter of
the clips completes before new clips start.  It also lets you fund
the account a little at a time.

If you like, as transcriptions trickle in, collect them and process the results so far:

- Click on Mechanical Turk's *Manage results*, *Download csv*.
- `mv Batch*.csv PTgen/test/myTest/batchfiles-raw`
- `cat PTgen/test/myTest/batchfiles-raw/Batch*.csv > PTgen/test/myTest/data/batchfiles/myLanguageCode/batchfile/Batches-downloaded.txt`
