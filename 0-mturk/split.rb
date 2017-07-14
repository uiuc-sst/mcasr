#!/usr/bin/env ruby

# For each .wav file foo.wav in the current directory,
# split it into clips, each slightly shorter than 1.25 seconds,
# named foo-usecStart-usecEnd.mp3 and .ogg.
#
# # For silent clips, instead of creating them,
# # accumulate their names into a .csv batchfile that pretends
# # to have come from turkers who transcribed them as "[silence]".
#
# Makes about 2800 clips per minute, singlethreaded.
# Runs at 18x real time, in other words.
#
# (Scavenged from PTgen/mturk/split.rb.)

$slice = 1.25 # longest duration of a clip, in seconds
$tmp = "/tmp/a.wav"
# $clipsSilent = []
`rm -rf #$tmp /tmp/a; mkdir /tmp/a`

begin
  c = 0
  d = 0.0
  Dir.glob("*.wav") {|wav|
    c += 1
    d += `sfinfo #{wav} | grep Duration`.split[1].to_f
  }
  STDERR.puts "Splitting #{c} .wav files into about #{(d/$slice).to_i*2} clips..."
end

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

    if false
      ampl = `sox #$tmp -n stat 2>&1 |grep "RMS     amplitude"`.split[2].to_f
      # 0.01 is too high a threshold: most of the 422 marked-silent clips had music and speech.
      # Of the 391 clips that 0.01 called silent but 0.0001 didn't, 18% had transcribable speech.
      # At 0.0001, 32 clips were marked silent.  That's not worth the trouble.
      # Maybe it'd be worth it if $slice were much shorter.
      if ampl < 0.0001
	$clipsSilent << clip
	next
      end
    end

    # Transcode to mp3 and to ogg.
    `sox #$tmp -C 160.2 /tmp/a/#{clip}.mp3` # 160 kbps
    `sox #$tmp -C 9     /tmp/a/#{clip}.ogg` # about 125 kbps
  }
}
`rm -rf #$tmp`
# File.open("clipsSilent.txt", "w") {|f| f.puts $clipsSilent.sort }
# STDERR.puts "Culled #{$clipsSilent.size} silent clips."
# STDERR.puts "Todo: convert clipsSilent.txt into a .csv batchfile."

$out = "/tmp/turkAudio.tar"
`rm -rf #$out; cd /tmp/a && tar cf #$out .`
puts "Copy #$out to ifp-serv-03 and extract it into /workspace/speech_web/mc/myTest."
