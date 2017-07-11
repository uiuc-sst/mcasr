#!/usr/bin/env ruby

# For each .wav file foo.wav in the current directory,
# split it into clips slightly shorter than 1.25 seconds
# named foo-usecStart-usecEnd.mp3 and .ogg.
#
# For silent clips, instead of creating them,
# accumulate their names into a .csv batchfile that pretends
# to have come from turkers who transcribed them as "[silence]".
#
# Construct batchfiles to submit to mturk.
#
# (Scavenged from PTgen/mturk/split.rb.)

$slice = 1.25 # seconds
$tmp = "/tmp/a.wav"
$clipsSilent = []
`rm -rf #$tmp /tmp/a; mkdir /tmp/a`

c = 0
d = 0.0
Dir.glob("*.wav") {|wav|
  c += 1
  d += `sfinfo #{wav} | grep Duration`.split[1].to_f
}
STDERR.puts "Splitting #{c} .wav files into about #{(d/1.25).to_i*2} clips..."
Dir.glob("*.wav") {|wav|
  dur = `sfinfo #{wav} | grep Duration`.split[1].to_f
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
    ampl = `sox #$tmp -n stat 2>&1 |grep "RMS     amplitude"`.split[2].to_f
    if ampl < 0.02
      $clipsSilent << clip
    else
      # Transcode to mp3 and to ogg.
      `sox #$tmp -C 160.2 /tmp/a/#{clip}.mp3` # 160 kbps
      `sox #$tmp -C 9     /tmp/a/#{clip}.ogg` # about 125 kbps
    end
  }
}
`rm -rf #$tmp`
File.open("clipsSilent.txt", "w") {|f| f.puts $clipsSilent }
STDERR.puts "Todo: convert clipsSilent.txt into a .csv batchfile."
STDERR.puts "Todo: convert /tmp/turkAudio.tar into something to submit to mturk."

$out = "/tmp/turkAudio.tar"
`rm -rf #$out; cd /tmp/a && tar cf #$out .`
puts "Copy #$out to ifp-serv-03 and extract it into /workspace/speech_web/mc/myTest."
