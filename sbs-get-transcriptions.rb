#!/usr/bin/env ruby

# Extract SBS transcriptions as "Leda" "Turker" phones.
# Run this on ifp-53.

$exp = "/home/lsari2/mc/mcasr/s5b/exp"
$data = "/home/lsari2/mc/mcasr/s5b/data"
`rm -rf /tmp/out; touch /tmp/out`
Dir.glob("#$exp/*") {|lang|
  next if lang =~ /_1$/ # skip dutch_1 which is a duplicate
  lang = File.basename lang
  puts lang
  `/ws/ifp-53_1/hasegawa/tools/kaldi/kaldi/src/bin/ali-to-phones #$exp/#{lang}/tri4b_ali/final.mdl ark:'gunzip -c #$exp/#{lang}/tri4b_ali/ali.*.gz|' ark,t:- | /ws/ifp-53_1/hasegawa/data/lorelei/mcasr/s5c/utils/int2sym.pl -f 2- #$data/#{lang}/lang/phones.txt >> /tmp/out`
}
