#!/usr/bin/env ruby

# Stitch turkers' transcriptions for Oromo 2017-08-17.
# Report timings in microseconds.  SR = 22050 Hz, if that matters.

# Clip: "http://isle.illinois.edu/mc/2018-08-17-orm/ORM_103_019-96094050-97342024.mp3"
# Transcription: "spud prudish perkumni".
# For each wavfile i.e. clip, hash to an array of transcriptions.
transcriptions = Hash.new {|k,v| k[v] = []}
#Cheaters = %w()

# Parse the original batchfile into a table of [clip, "transcription"].
# Each line: the "ORM_103_019-96094050-97342024.mp3"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
require 'csv'
CSV.foreach('/r/lorelei/oromo/batchAll.csv') {|r|
  #next if Cheaters.include? r[15]

  # Only mp3's.  Keep only the unique part.  Map "057_004-23619714-24862856" to ["057_004", 23619714, 24862856].
  wavs = r[27..42].select {|c| c =~ /mp3/} \
    .map {|l| l.sub("http://isle.illinois.edu/mc/2018-08-17-orm/ORM_", "") .sub(".mp3", "") } \
    .map {|l| a = l.split "-"; [a[0], a[1].to_i, a[2].to_i]}
  # These timings are in microseconds, not in 1/22050 of a second.
  scrips = r[45..52]
  next if wavs.size != 8 || scrips.size != 8 # This is a header line.  Ignore it.

  [wavs, scrips].transpose.each {|w,t|
    t.downcase!
    t.gsub! /^text goes here/, ' '
    t.gsub! /^text goes her/, ' '
    t.gsub! /^text goes he/, ' '
    t.gsub! /^text goes h/, ' '
    t.gsub! /^text goes /, ' '
    t.gsub! /^text goes/, ' '
    t.gsub! /^text goe/, ' '
    t.gsub! /^text go/, ' '
    t.gsub! /^text g/, ' '
    t.gsub! /^text /, ' '
    t.gsub! '"', ' ' # Avoid "CSV_XS ERROR: 2023 - EIQ - QUO character not allowed" from preprocess_turker_transcripts.pl's Text::CSV_XS, because the CSV is naively resynthesized with string manipulation instead of a proper CSV parser.

    # Add spaces around the outside of brackets, just in case.
    t.gsub! "[", " ["
    t.gsub! "{", " {"
    t.gsub! "(", " ("
    t.gsub! "]", "] "
    t.gsub! "}", "} "
    t.gsub! ")", ") "

    t.gsub! '"music"', ' [music] '

    # If t's only letters are "music", normalize it, no matter what kind of brackets, or even missing brackets.
    onlyletters = t.gsub(/[^a-z]/, '')
    t = ' [music] ' if onlyletters == "music" || onlyletters.split(//).sort.join == "cimsu" # typos
    t = ' [sound] ' if onlyletters == "sound"
    t = ' [empty] ' if onlyletters == "empty"
    t = ' [noise] ' if onlyletters == "noise"

    # Convert any newlines to spaces.
    t.gsub! "\r\n", " "
    t.gsub! "\r", " "
    t.gsub! "\n", " "

    # Omit trailing punctuation
    t = t.strip.sub /[;,\.\?\!]$/, ''

    # todo: handle transcriptions that mistakenly put [] around valid transcription text (nonsense words) instead of around comments (valid english words).

    t.gsub! /\s+/, ' '
    t = t.strip
    t = "" if t =~ /yummm/ || t =~ /mmmm/ || t =~ /hhhh/ || t =~ /pppp/ || t =~ /nnnn/ || t =~ /uuuu/ || t =~ /rrrr/ # Omit spam.
    transcriptions[w] << t if !t.empty?
  }
}
$t = transcriptions.to_a.sort_by {|x| x[0]}
# Collect each utterance's clips+transcriptions.
$u = Hash.new {|k,v| k[v] = []}
$t.each {|wav,t|
  # wav = ["008_003", 84492463, 85734999]
  # t = ["dejuenier", "udeshunnehra", "tonashanegra"]
  utt = wav[0] # "008_003"
  clip = wav[1..2] # [84492463, 85734999]
  $u[utt] << clip + [t]
}

`rm -rf clips-oromo.tar clips-oromo; mkdir clips-oromo`
$u.each {|utt,clips|
  File.open("clips-oromo/" + utt + ".txt", "w") {|f|
    clips.to_a.sort_by {|x| x[0]} \
      .each {|c| f.puts "#{c[0]} #{c[1]} #{c[2].sort.uniq.join(' # ')}" }
  }
}
`tar cf clips-oromo.tar clips-oromo`
