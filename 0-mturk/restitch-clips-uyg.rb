#!/usr/bin/env ruby

# This may run only on zx81 in /r/lorelei/dry/mturk.

require 'interpolate' # github.com/m104/interpolate, gem install interpolate

$ldcNames,$offsets = File.readlines('offsetsLDC-filenames.txt') .map {|l| l.chomp.split("\t")} .transpose
$offsets.map! {|i| i.to_i}

# Change 22k-sample-offsets into a.wav to offsets into b.wav,
# by lerping in silenceremoval-22k.txt, mapping col 1 to col 2.
# And the reverse.
begin
  pairs = File.readlines('silenceremoval-22k.txt') .map {|l| l.chomp.split.map(&:to_f)}
  $a2b = Interpolate::Points.new Hash[pairs]
  $b2a = Interpolate::Points.new Hash[pairs.map {|l| l.reverse }]
end

# Given an LDC filename, return which turker-transcribed clips contain its transcriptions.
def clipsFromFilename(wavfile)
  iName = $ldcNames.find_index(wavfile)
  # iBgn and iEnd are 22050-Hz offsets into a.wav.
  iBgn = $offsets[iName]
  iEnd = $offsets[iName+1] - 1
  # iClip* are integer indices of clips.
  # /27562.5 converts 22050 Hz frame offset to 1.25-s-long-clip index
  # (clips are 1.3 s long, but spaced by 1.25 s).
  # The 0.5's give successive filenames an overlap of exactly 1 clip.  Close enough.
  # IOW, one wav's last clip = the next wav's first clip.
  # That clip includes both the end of one wav and the start of the next wav.
  # (The temporal boundary between wav's could be reconstructed from durations in Uzbek/LDC2016E66,
  # but because we can't reconstruct where to split a transcription, we can't exploit that info.)

  iClipBgn = ($a2b[iBgn] / 27562.5 + 0.5).floor
  iClipEnd = ($a2b[iEnd] / 27562.5 - 0.5).ceil
  return iClipBgn, iClipEnd
end

clips = []
Dir.chdir("/zx/trash/22k/") { Dir.glob("*.wav") {|wav| clips << [wav] + clipsFromFilename(wav) }}
$clips = clips.sort_by {|wav,*| wav}

# Concatenate those transcriptions.
# /r/lorelei/PTgen/test/2016-11-28/data/batchfiles/UY/batchfile
# Clip: "http://isle.illinois.edu/mc/uyghurDryrun/00019.mp3"
# Transcription: "Permushfado".

transcriptions = Array.new(46749) { [] }; # An empty array for each clip.

# Parse the original batchfile into a table of [iClip, "transcription"].
# Each line: the "99999.mp3"'s, then the last 8 column-delimited "strings".
# Indices are documented in preprocess_turker_transcripts.pl.
require 'csv'
# cd /r/lorelei/PTgen/test/2016-11-28; cat batchfiles-raw/Batch* > data/batchfiles/UY/batchfile
raw = CSV.read('/r/lorelei/PTgen/test/2016-11-28/data/batchfiles/UY/batchfile')
raw.each {|r|
  mp3s = r[27..41].select {|c| c =~ /mp3/} .map {|l| l.match(/[0-9]+/)[0].to_i } # Only mp3's; then keep only the number.
  scrips = r[45..52]
  next if mp3s.size != 8 || scrips.size != 8 # This is a header line.  Ignore it.
  [mp3s, scrips].transpose.each {|c,t|
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
    t.gsub! /text goes here$/, ' '
    t.gsub! /ext goes here$/, ' '
    t.gsub! /xt goes here$/, ' '
    t.gsub! /t goes here$/, ' '
    t.gsub!(/ goes here$/, ' ')
    t.gsub! /goes here$/, ' '
    t.gsub! /oes here$/, ' '
    t.gsub! /es here$/, ' '
    t.gsub! /s here$/, ' '
    t.gsub!('"', ' ') # Avoid "CSV_XS ERROR: 2023 - EIQ - QUO character not allowed" from preprocess_turker_transcripts.pl's Text::CSV_XS, because the CSV is naively resynthesized with string manipulation instead of a proper CSV parser.

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
    t.gsub!("\r\n", " ")
    t.gsub!("\r", " ")
    t.gsub!("\n", " ")

    # Omit trailing punctuation
    t = t.strip.sub /[;,\.\?\!]$/, ''

    t.gsub! /\s+/, ' '
    t = t.strip
    t = "" if t =~ /mmm/ || t =~ /hhh/ || t =~ /nnnn/ || t =~ /pppp/ || t =~ /sdf/ || t =~ /sfd/ || t =~ /fdg/ || t =~ /fgd/ || t =~ /noseavenue/ || t =~ /radabackshogun/ || t =~ /sdg/ || t =~ /budane/ || t =~ /kowajungle/ # Omit spam.
    transcriptions[c] << t if !t.empty?
  }
}
# Each entry in transcriptions is a (possibly empty) array of clip-transcriptions.

# From b.wav, split.rb extracted evenly spaced clips starting at i*1.25 seconds into i.mp3.
# Clip offsets into b.wav are multiples of 1.25 seconds, or of 27562.5 samples.
# So, iClipBgn and iClipEnd's offsets into b.wav are:
# iClipBgn * 27562.5
# iClipEnd * 27562.5
# For c in that range, each clip's b.wav-offset is c*27562.5 .. (c+1)*27562.5.
# Clip c's a.wav-offset is then $b2a[c*27562.5] .. $b2a[(c+1)*27562.5].

# Stitch together the transcriptions.
`rm -rf clips-uyghur.tar clips-uyghur; mkdir clips-uyghur`
def bak(c) $b2a[c*27562.5] # Offset in 22050Hz samples into a.wav of start of clip c.
end
$clips.each {|wav,c1,c2|
  File.open("clips-uyghur/" + wav[0..-5] + ".txt", "w") {|f|
    (c1..c2).each {|c|
      t = transcriptions[c]
      next if t.empty? # Clip c had no transcriptions.  (This happened only 5 times.)
      clipStart = bak(c1)
      # Print 22K offsets into a.wav of start and end of clip c.
      f.puts "#{(bak(c)-clipStart).to_i} #{(bak(c+1)-clipStart).to_i} #{t.sort.uniq.join(" # ")}"
    }
  }
}
`tar cf clips-uyghur.tar clips-uyghur`
