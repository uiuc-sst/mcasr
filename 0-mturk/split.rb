#!/usr/bin/env ruby

# For each .wav file foo.wav in the current directory,
# split it into clips, each slightly shorter than 1.25 seconds,
# named foo-usecStart-usecEnd.mp3 and .ogg.
#
# Makes about 2800 clips per minute, singlethreaded.
# Runs at 18x real time, in other words.

$slice = 1.25 # Longest duration of a clip, in seconds.
$tmp = "/tmp/a.wav"
`rm -rf #$tmp /tmp/a; mkdir /tmp/a`

def seconds(wav)
# `sfinfo #{wav} | grep Duration`.split[1].to_f
  `soxi -D #{wav}`.to_f
end

begin
  c = 0
  d = 0.0
  Dir.glob("*.wav") {|wav|
    c += 1
    d += seconds(wav)
  }
  STDERR.puts "Splitting #{c} .wav files, totaling #{'%.1f' % (d/3600.0)} hours, into about #{(d/$slice).to_i*2} clips..."
  STDERR.puts "This should take about #{(d/1200).to_i} minutes."
end

# Before multithreading this loop, make a different $tmp for each thread.
Dir.glob("*.wav") {|wav|
  dur = seconds(wav)
  n = (dur/$slice).ceil
  l = dur/n
  puts "Splitting #{wav}, #{dur} s, into #{n} clips each #{'%.2f' % l} s long." if false
  n.times {|i|
    start = i * l
    args = start.to_s
    args += " #{l}" if i < n-1 # Avoid sox's warning "1 sample too far."
    `sox #{wav} #$tmp trim #{args}`
    usecBgn = ( i   *l * 1e6).to_i
    usecEnd = ((i+1)*l * 1e6).to_i - 1
    clip = "#{wav[0..-5]}-#{usecBgn}-#{usecEnd}"

    # Transcode to mp3 and to ogg.
    `sox #$tmp -C 160.2 /tmp/a/#{clip}.mp3` # 160 kbps
    `sox #$tmp -C 9     /tmp/a/#{clip}.ogg` # about 125 kbps
  }
}
`rm -rf #$tmp`

$out = "/tmp/turkAudio.tar"
`rm -rf #$out; cd /tmp/a && tar cf #$out .`
puts "Copy #$out to ifp-serv-03 and extract it into /workspace/speech_web/mc/myTest."
