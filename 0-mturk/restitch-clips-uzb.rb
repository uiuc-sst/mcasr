#!/usr/bin/env ruby

# Stitch transcriptions.
# Report timings: Uzbpart-21/UZB_999_999.wav UZB_999_999.wav sampleBgn sampleEnd
#
# Source data is described in PTgen/test/2016-08-24/a.txt.
#
# .wav's listened to by turkers:
#   /workspace/speech_web/uzbek/splitUZB/* 6.8 GB (flacs and wavs.  Use soxi to get durations.)

# Timings come from:
# cd /ws/ifp-serv-03_1/workspace/fletcher/fletcher1/speech_data1/Uzbek/LDC2016E66/UZB_20160711
# paste <(find . -name \*flac) <(find . -name \*flac| xargs soxi | grep samples)
# Tidied the result with vi, into ./restitch-clips-uzbek-timings.txt.
# Timings are at 44100 Hz, from soxi one of those .flac's.
timings = File.readlines("restitch-clips-uzbek-timings.txt") .map {|l|
  a = l.split              # ["UZB_052_001", "2980146"]
  [a[0][4..-1], a[1].to_i] # [    "052_001",  2980146 ]
}
$timings = Hash.new
timings.each {|utt,samples| $timings[utt] = samples}

# Clip: "http://www.isle.illinois.edu/uzbek/splitUZB/Uzbpart-21/UZB_111_001.wav"
# Transcription: "Itsyoufaltendeau".
# 84960 == `find /homes/xkong12/splitUZB -name \*flac |wc -l`.to_i
# 31824 is how many clips got at least one transcription.
# For each wavfile i.e. clip, hash to an array of transcriptions.
transcriptions = Hash.new {|k,v| k[v] = []}

# Parse the original batchfile into a table of [clip, "transcription"].
# Each line: the "Uzbpart-21/UZB_333_001.wav"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
require 'csv'
`cat /r/lorelei/PTgen/test/2016-08-24/batchfiles-raw/Batch_*_batch_results.csv > /tmp/batchfile`
# batch_results.csv lacks any Uzbpart-59 and Uzbpart-60.
raw = CSV.read('/tmp/batchfile')
raw.each {|r|
  # Only wav's.  Then keep only the unique part.  Then map "31/UZB_374_002" to "374_002_31".
  wavs = r[27..42].select {|c| c =~ /wav/} \
    .map {|l| l.sub("http://www.isle.illinois.edu/uzbek/splitUZB/Uzbpart-", "") .sub(".wav", "") } \
    .map {|l| a = l.split "/"; part = "%02d" % a[0].to_i; a[1][4..-1] + "_" + part }
  scrips = r[45..52]
  next if wavs.size != 16 || scrips.size != 8 # This is a header line.  Ignore it.
  wavs = wavs.values_at(* wavs.each_index.select(&:even?)) # Keep every second entry.
  [wavs, scrips].transpose.each {|w,t|
    t.downcase!
    t.gsub!('text goes here', ' ')
    t.gsub!('text goes her', ' ')
    t.gsub!('text goes ', ' ')
    t.gsub!('"', ' ') # Avoid "CSV_XS ERROR: 2023 - EIQ - QUO character not allowed" from preprocess_turker_transcripts.pl's Text::CSV_XS, because the CSV is naively resynthesized with string manipulation instead of a proper CSV parser.

    # If t's only letters are "music", normalize it, no matter what kind of brackets, or even missing brackets.
    t = ' [music] ' if t.gsub(/[^a-z]/, '') == "music"
    # That misses the case t == "(music)adhimu".  So,
    t.gsub!('(music)', '[music]')
    t.gsub!('(empty)', '[empty]')
    t.gsub!('(noise)', '[noise]')
    t.gsub!('(sound)', '[sound]')

    # Convert any newlines to spaces.
    t.gsub!("\r\n", " ")
    t.gsub!("\r", " ")
    t.gsub!("\n", " ")

    t = t.strip
    t = "" if t =~ /mmm/ || t =~ /hhh/ || t =~ /nnnn/ || t =~ /pppp/ || t =~ /sdf/ || t =~ /sfd/ || t =~ /fdg/ || t =~ /fgd/ || t =~ /noseavenue/ || t =~ /radabackshogun/ || t =~ /sdg/ || t =~ /budane/ || t =~ /kowajungle/ # Omit spam.
    # Spam is easy to detect when all other transcriptions of a clip are [music]'s.
    # Or find words that occur unusually often, like more than 3 times.
    # Which turker made this in Uyghur?  Omit *all* his HITs?
    transcriptions[w] << t if !t.empty?
  }
}
$t = transcriptions.to_a.sort_by {|x| x[0]}

# Collect each UZB_999_999 utterance's clips+transcriptions.
$u = Hash.new {|k,v| k[v] = []}
$t.each {|wav,t|
  utt = wav[0..6] # "026_002"
  clip = wav[8..9].to_i # 9
  $u[utt] << [clip, t]
}

`rm -rf clips-uzbek.tar clips-uzbek; mkdir clips-uzbek`
$u.each {|utt,clips|
  File.open("clips-uzbek/" + utt + ".txt", "w") {|f|
    clips.to_a.sort_by {|x| x[0]} \
      .each {|c|
        csamplesUtt = $timings[utt]
        i = c[0]-1 # 0 to 59
	sampleBgn = (csamplesUtt * ( i    / 60.0)).to_i
	sampleEnd = (csamplesUtt * ((i+1) / 60.0)).to_i
	f.puts "#{sampleBgn} #{sampleEnd} #{c[1].sort.uniq.join(' # ')}"
      }
  }
}
`tar cf clips-uzbek.tar clips-uzbek`
