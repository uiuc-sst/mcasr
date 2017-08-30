#!/usr/bin/env ruby

# Stitch turkers' transcriptions for Tigrinya 2017-08-17.
# Report timings in microseconds.  SR = 22050 Hz, if that matters.

# Clip: "http://isle.illinois.edu/mc/2018-08-17-tir/TIR_103_019-96094050-97342024.mp3"
# Transcription: "spud prudish perkumni".
# For each wavfile i.e. clip, hash to an array of transcriptions.
transcriptions = Hash.new {|k,v| k[v] = []}
Cheaters = %w(A1IOMFFEKCWOIT A1ZSFIIIU3WH9G A23F4NFSHEZMDL A28FMRMS9TMEOZ A298J6JKK4Q2XN A2FZ88OU42EFC8 A2MPEH2IT5MWKW A2PU4YNWITAQVL A2S2OS8CIO5END A2VI8XH6A1PB27 A33BMZB3JCJWDS A3DDIOMFJ5UUNV A3GMT4AGHPT362 A3Q1YUOX8U5O6C A3VHDQR8A9JJ4F A68Q94ZY24XAL AEBETUY5OD68H AMMER6L16WFVS AP9YUQ68FFZKY AXZJZZDA4FBJ3 AYFHTI4Y6RG83)

# Parse the original batchfile into a table of [clip, "transcription"].
# Each line: the "TIR_103_019-96094050-97342024.mp3"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
require 'csv'
CSV.foreach('/r/lorelei/aug/bat/tir/all.csv') {|r|
  next if Cheaters.include? r[15]

  # Only mp3's.  Keep only the unique part.  Map "057_004-23619714-24862856" to ["057_004", 23619714, 24862856].
  wavs = r[27..42].select {|c| c =~ /mp3/} \
    .map {|l| l.sub("http://isle.illinois.edu/mc/tigrinya/IL5_EVAL_", "") .sub(".mp3", "") } \
    .map {|l| a = l.split "-"; [a[0], a[1].to_i, a[2].to_i]}
  # These timings are in microseconds, not in 1/22050 of a second.
  scrips = r[45..52]
  next if wavs.size != 8 || scrips.size != 8 # This is a header line.  Ignore it.
  next if r[16] != "Approved" # about 3700 of 74000

  [wavs, scrips].transpose.each {|w,t|
    t.downcase!
    t.gsub! /clip .\/8\: 0\:00 \/ 0\:01 /, ''
    t.gsub! /text goes here/, ' '
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

    # Verbosities.
    t.gsub! "in clip", " "
    t.gsub! /\bmr /, " mister " # Not uncommon!  (\b is word boundary: ^ or whitespace.)

    # Synonyms.
    t = ' [empty] ' if t =~ /this clip/
    t = ' [empty] ' if t =~ /n\/a/
    t = ' [music] ' if %w(x c - --- . .. ... ....).include? t # c is a typo for x

    # Strip punctuation.
    t.gsub! /[=\:\.,]/, ' '

    # Add spaces around the outside of brackets, just in case.
    t.gsub! "[", " ["
    t.gsub! "{", " {"
    t.gsub! "(", " ("
    t.gsub! "]", "] "
    t.gsub! "}", "} "
    t.gsub! ")", ") "

    # If t's only letters are "music", normalize it, no matter what kind of brackets, or even missing brackets.
    onlyletters = t.gsub(/[^a-z ]/, '')
    t = ' [music] ' if onlyletters =~ /only music/
    t = ' [music] ' if onlyletters =~ /music played/

    t = ' [empty] ' if onlyletters =~ /^clip no/
    t = ' [empty] ' if onlyletters =~ /^no clip/
    t = ' [empty] ' if onlyletters =~ /sound doesn't work/
    t = ' [empty] ' if onlyletters =~ /no sound/

    t = ' [noise] ' if onlyletters =~ / noise$/
    t = ' [noise] ' if onlyletters =~ /only noise/
    t = ' [noise] ' if onlyletters =~ / sound$/
    t = ' [noise] ' if onlyletters =~ / sounds$/

    t = ' [music] ' if %w(music ding song background\ music).include?(onlyletters) || onlyletters.split(//).sort.join == "cimsu" # typos
    t = ' [sound] ' if %w(sound nonspeech nonspeach).include? onlyletters
    t = ' [noise] ' if %w(noise not\ clear applause clapping cheer cheering static).include? onlyletters
    t = ' [empty] ' if %w(empty empy emty mt empry blank soundno no\ sound no\ audio silent silence air breath inaudible).include? onlyletters

    # Convert any newlines to spaces.
    t.gsub! "\r\n", " "
    t.gsub! "\r", " "
    t.gsub! "\n", " "

    # Omit trailing punctuation
    t = t.strip.sub /[;,\.\?\!]$/, ''

    # Compress tripled-or-more letters "aaa" to doubled letters "aa".
    t.gsub! /(.)\1{2,}/, '\1\1'

    # todo: handle transcriptions that mistakenly put [] around valid transcription text (nonsense words) instead of around comments (valid english words).

    t.gsub! /\s+/, ' '
    t = t.strip
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

`rm -rf clips-tigrinya.tar clips-tigrinya; mkdir clips-tigrinya`
$u.each {|utt,clips|
  File.open("clips-tigrinya/" + utt + ".txt", "w") {|f|
    clips.to_a.sort_by {|x| x[0]} \
      .each {|c| f.puts "#{c[0]} #{c[1]} #{c[2].sort.join(' # ')}" }
      # Not sort.uniq, to reveal majority opinion.
  }
}
`tar cf clips-tigrinya.tar clips-tigrinya`
