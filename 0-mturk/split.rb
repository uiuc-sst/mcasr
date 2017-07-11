#!/usr/bin/env ruby

# For each .wav file in the current directory,
# split it into 1.25 second clips, in .mp3 and .ogg format.
# Store timing info in each clip's filename.
# If any clips are pure silence,
# append that filename to a list, and delete the file.
# From that list of silent clips,
# create a .csv batchfile that pretends to have come from turkers transcribed these clips as "[silence]".
# Construct batchfiles to submit to mturk.
#
# (Scavenged from PTgen/mturk/split.rb.)

$slice = 1.25 # seconds
$tmp = "/tmp/a.wav"
$clipsSilent = []

Dir.glob("*.wav") {|wav|
  $dur = `sfinfo #{wav} | grep Duration`.split[1].to_f
  n = ($dur/$slice).ceil
  l = $dur/n
  puts "Splitting #{wav}, #$dur s, into #{n} clips each #{'%.2f' % l} s long." if false
  n.times {|i|
    start = i * l
    args = start.to_s
    args += " #{l}" if i < n-1 # Avoid sox's warning "1 sample too far."
    `sox #{wav} #$tmp trim #{args}`
    usecBgn = (start   * 1e6).to_i
    usecEnd = ((i+1)*l * 1e6).to_i - 1
    clip = "#{wav[0..-5]}-#{usecBgn}-#{usecEnd}.mp3"
    puts clip
    `sox #$tmp -C 160 #{clip}`			# 160 kbps
    `sox #$tmp -C 9 #{clip[0..-5] + ".ogg"}`	# roughly 125 kbps
  }
}
