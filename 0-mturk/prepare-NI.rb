#!/usr/bin/env ruby
# encoding: utf-8

# Reformat native informant (NI) transcriptions for MCASR.

DirOut = "/ws/ifp-53_1/hasegawa/data/lorelei/mcasr/s5c/scrips-orm-NI/"
DirIn  = "/ws/ifp-53_1/hasegawa/data/lorelei/PTgen/native-scrips-il6/"
ScripsIn = DirIn + "transcription.txt"
WavsIn   = DirIn + "out/"

# In ScripsIn, each line is a wavfile-prefix, whitespace, transcription, e.g.
#     2017-08-08-il6ni6-213 jedhan harkaafi miila irraa ciruun tumtu taasisan.
$scripsIn = File.readlines(ScripsIn) .map {|l| l.chomp.strip } .map {|l| [l.sub(/\s.*/, ''), l.sub(/[^\s]*\s*/,'')]}

# Lower case.  Remove punctuation.  Coalesce whitespace.
# (The Oromo NI carefully uses “”‘’ for quotes, ʼ for diacritics.)
$scripsIn.map! {|name,scrip| [name, scrip.downcase.gsub(/[\.,\?\!–\-\:\;\(\)\*“”‘’]/,' ').gsub(/[\s]+/,' ').strip]}
# todo: listen.  Are parenthesized English phrases actually spoken?:
# ( centralized form of government )
# ( administrative boundary )
# “ federal land development corporation ”
# ( consensus based )
# (“ ecology “)

$scripsIn.each {|name,scrip|
  # -1 avoids roundoff error past the end of file.
  usecDur = (`soxi -D #{WavsIn}#{name}.wav`.to_f * 1e6).to_i - 1
  File.open(DirOut+name+".txt", "w") {|f| f.puts "0 #{usecDur} #{scrip}"}
}
