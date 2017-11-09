#!/usr/bin/env ruby

# Stitch transcriptions.

# Clip: "http://www.ifp.illinois.edu/~pjyothi/mfiles/ws15/arabic/part-3/arabic_141120_374643-2.mp3"
# Transcription: "een oboo faaj".
# For each wavfile i.e. clip, hash to an array of transcriptions.
transcriptions = Hash.new {|k,v| k[v] = []}

# /r/lorelei/sbs-audio/dutch-wav/dutch_140903_358463-*.wav, -1.wav to -20.wav are each 5 to 8 s long.
# Originals are on 
#   rizzo.ifp.uiuc.edu:/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/audio/
#   rizzo.ifp.uiuc.edu:/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/transcripts/matched/
# (The only missing file was hungarian_unlabeled/hungarian_141115_373583-5.wav.)
# Each wav was split into 4 mp3s of roughly the same duration.
#
# Build turker scrips for mcasr, using equal-split for the offsets into each .wav.
#
# ifp-53:~/l/ws15% ruby -e 'Dir.glob("*/*.wav").each {|f| puts "#{(`soxi -s #{f}`.to_i * 1000000) / 16000} #{f}" }' > ws15-durs.txt
wavToDurUsec = Hash[ File.readlines('ws15-durs.txt') .map \
  {|l| usec,wav=l.split; [wav.sub(/[^\/]+\//,'').sub('.wav',''), usec.to_i]} ]

# Convert source files from DOS format, and append a newline just in case.
`awk '{print $0}' /r/lorelei/PTgen/test/ws15/data-WS15/batchfiles/*/batchfile | tr -d '\015' > /tmp/batchfile`
# Parse the original batchfile into a table of [clip, "transcription"].
# Each line: the "Uzbpart-21/UZB_333_001.wav"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
require 'csv'
CSV.foreach('/tmp/batchfile') {|r|
  # Only mp3's.  Then keep only the unique part.
  # Then map arabic/part-3/arabic_141217_380249-7 to 3/arabic_141217_380249-7.
  wavs = r[27..42].select {|c| c =~ /mp3/} \
    .map {|l| l.sub("http://www.ifp.illinois.edu/~pjyothi/mfiles/ws15/", "") \
	       .sub(".mp3", "") .sub(/[^\/]*\/part-/, "") }
  scrips = r[45..52]
  next if wavs.size != 8 || scrips.size != 8 # This is a header line.  Ignore it.
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
    t = "" if t =~ /mmm/ || t =~ /nnnn/ || t =~ /pppp/ || t =~ /sdf/ || t =~ /sfd/ || t =~ /fdg/ || t =~ /fgd/ || t =~ /noseavenue/ || t =~ /radabackshogun/ || t =~ /sdg/ || t =~ /budane/ || t =~ /kowajungle/ # Omit spam.
    # Spam is easy to detect when all other transcriptions of a clip are [music]'s.
    # Or find words that occur unusually often, like more than 3 times.
    transcriptions[w] << t if !t.empty?
  }
}
$t = transcriptions.to_a.sort_by {|x| x[0]}

# Collect each utterance's clips+transcriptions.
$u = Hash.new {|k,v| k[v] = []}
$t.each {|mp3,t|
  part,utt = mp3.split '/'
  $u[utt] << [part.to_i, t]
}

`rm -rf clips-ws15.tar clips-ws15; mkdir clips-ws15`
$u.each {|utt,clips|
  File.open("clips-ws15/" + utt + ".txt", "w") {|f|
    clips.to_a.sort_by {|x| x[0]} \
      .each {|c|
        dur = wavToDurUsec[utt]
	if !dur
	  puts "Skipping file missing from ~/l/ws15: #{utt}.wav"
	  next
	end
        i = c[0] # 1 to 4
	usecBgn = (dur * ((i-1)*0.25)).to_i
	usecEnd = (dur * ( i   *0.25)).to_i
	f.puts "#{usecBgn} #{usecEnd} #{c[1].sort.join(' # ')}" # Don't .uniq, to help PTgen measure distance between scrips.
      }
  }
}
`tar cf clips-ws15.tar clips-ws15`
