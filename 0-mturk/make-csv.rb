#!/usr/bin/env ruby

# Create a .csv file listing audio clips in randomly shuffled order.
#
# Run this after running ./split.rb, so its /tmp/a directory still contains the clips.
# Send the output of this script to foo.csv, and then to Mechanical Turk's "Publish Batch".

if ARGV.size != 1
  STDERR.puts "Usage: #$0 dirName"
  # E.g., for /workspace/speech_web/mc/2017-07-12-rus aka
  # http://isle.illinois.edu/mc/2017-07-12-rus/*.mp3,
  #
  #     ./make-csv.rb 2017-07-12-rus > to_mturk.csv.
  exit 1
end

WAVS = Dir.glob("/tmp/a/*.mp3") .map {|w| w[7..-5]} # Strip /tmp/a/ and .mp3.
N = WAVS.size
# STDERR.puts "#{N} * 2 clips."

puts "audio1,oggaudio1,audio2,oggaudio2,audio3,oggaudio3,audio4,oggaudio4,audio5,oggaudio5,audio6,oggaudio6,audio7,oggaudio7,audio8,oggaudio8"

URL = "http://isle.illinois.edu/mc/" + ARGV[0] + "/"
ClipNumbers = WAVS.shuffle

# Partition into 8-tuples, excluding any remainder.
ClipNumbers[0 ... (N/8) * 8] .each_slice(8) {|octuple|
  octuple.each_with_index {|filename,j|
    comma = j<7 ? "," : ""
    print "#{URL}#{filename}.mp3,#{URL}#{filename}.ogg#{comma}"
  }
  puts ""
}
