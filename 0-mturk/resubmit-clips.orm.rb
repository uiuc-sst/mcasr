#!/usr/bin/env ruby

# Make a batch of clips to resubmit,
# because they were by later-blocked cheaters,
# or had other problems.
# Copied from restitch-clips-orm.rb.

require 'csv'
$mp3s = []
CSV.foreach('/r/lorelei/aug/to-mturk-oromo.csv') {|r|
  wavs = r[0..16].select {|c| c =~ /mp3/}
  next if wavs.size != 8 # This is a header line.  Ignore it.
  $mp3s += wavs
}
STDERR.puts "#$0: #{$mp3s.size} mp3s."
$mp3s = $mp3s.sort
# $mp3s.uniq! # Fortunately does nothing.

# Clip: "http://isle.illinois.edu/mc/2018-08-17-orm/ORM_103_019-96094050-97342024.mp3"
# Transcription: "spud prudish perkumni".
# For each wavfile i.e. clip, hash to an array of transcriptions.
transcriptions = Hash.new {|k,v| k[v] = []}
Cheaters = %w(A1IOMFFEKCWOIT A1ZSFIIIU3WH9G A23F4NFSHEZMDL A28FMRMS9TMEOZ A298J6JKK4Q2XN A2FZ88OU42EFC8 A2MPEH2IT5MWKW A2PU4YNWITAQVL A2S2OS8CIO5END A2VI8XH6A1PB27 A33BMZB3JCJWDS A3DDIOMFJ5UUNV A3GMT4AGHPT362 A3Q1YUOX8U5O6C A3VHDQR8A9JJ4F A68Q94ZY24XAL AEBETUY5OD68H AMMER6L16WFVS AP9YUQ68FFZKY AXZJZZDA4FBJ3 AYFHTI4Y6RG83)

# Parse the original batchfile into a table of [clip, "transcription"].
# Each line: the "ORM_103_019-96094050-97342024.mp3"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
CSV.foreach('/r/lorelei/aug/bat/orm/all.csv') {|r|
  next if Cheaters.include? r[15]

  # Only mp3's.  Keep only the unique part.  Map "057_004-23619714-24862856" to ["057_004", 23619714, 24862856].
  mp3s = r[27..42].select {|c| c =~ /mp3/}
  wavs = mp3s.map {|l| l.sub("http://isle.illinois.edu/mc/oromo/IL6_EVAL_", "") .sub(".mp3", "") } \
    .map {|l| a = l.split "-"; [a[0], a[1].to_i, a[2].to_i]}
  # These timings are in microseconds, not in 1/22050 of a second.
  scrips = r[45..52]
  next if wavs.size != 8 || scrips.size != 8 # This is a header line.  Ignore it.
  next if r[16] != "Approved" # about 1200 of 46000

  [mp3s, scrips].transpose.each {|w,t|
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
    t = ' [empty] ' if onlyletters =~ /no sound$/

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

    # todo: handle transcriptions that mistakenly put [] around valid transcription text (nonsense words) instead of around comments (valid english words).

    t.gsub! /\s+/, ' '
    t = t.strip
    transcriptions[w] << t # if !t.empty?
  }
}
STDERR.puts "#$0: #{transcriptions.size} clips have (possibly empty) transcriptions."
$agains = []
$mp3s.each {|mp3|
  t = transcriptions[mp3].select {|scrip| !scrip.empty?} # Omit "" scrips.
  # About 650 t's have size < 3.
  again = t == nil || t.size < 3
  again |= t.join =~ /clip/ && t.join !~ /music/	# Redo if "clip", but not if also "music."
  again &= !(t.size == 2 && t[0] == t[1])		# Don't redo, if only 2 scrips but they agree.
  again &= !(t.size==3 && t.uniq.size < 3)		# Don't redo, if 2 or more scrips agree, e.g., [music] or [empty].

  # More tests for the t.size==3 ones?
  # && (t =~ /uhh/ || t =~ /umm/)

  # puts "#{mp3} -> #{t}" if again
  # http://isle.illinois.edu/mc/oromo/IL6_EVAL_006_003-47349876-48595924.mp3 -> ["[music]", "doododoodooo", "[music]"]
  $agains << mp3[0..-5] if again # Strip .mp3.
}
STDERR.puts "Analyzed transcriptions."
$agains = $agains.shuffle

`rm -rf newclips-oromo.csv`
File.open("newclips-oromo.csv", "w") {|f|
  # Copied from mcasr/0-mturk/make-csv.rb.
  f.puts "audio1,oggaudio1,audio2,oggaudio2,audio3,oggaudio3,audio4,oggaudio4,audio5,oggaudio5,audio6,oggaudio6,audio7,oggaudio7,audio8,oggaudio8"
  # Partition into 8-tuples, excluding any remainder.
  N = $agains.size
  $agains[0 ... (N/8) * 8] .each_slice(8) {|octuple|
    octuple.each_with_index {|filename,j|
      comma = j<7 ? "," : ""
      f.print "#{filename}.mp3,#{filename}.ogg#{comma}"
    }
    f.puts ""
  }
}
STDERR.puts "Fresh batch is in newclips-oromo.csv."
