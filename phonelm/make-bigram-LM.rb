#!/usr/bin/env ruby
# encoding: utf-8

# Make a bigram LM from the phone sequences in Wenda's prondict.
# On stdin, expects e.g. prondict_uzbek-from-wenda.txt or prondicts/rus-prondict-july26.txt,
# where each line is a word, tab-or-space, space-delimited IPA phones.

# Read those phone seqs.
$phoneSeqs = ARGF.readlines.map {|l| l.chomp} .map {|l| l.sub(/[^\s]*\s/, '').strip} .delete_if {|l| l =~ / ABORT$/}
$phoneFile="/r/lorelei/PTgen/mcasr/phones.txt"
$phones = File.readlines($phoneFile) .map {|l| l.split[0]} .sort
STDERR.puts "Phones parsed."

if false
  require 'set'
  used = Set.new
  $phoneSeqs.sort.uniq.each {|s| used.merge s.split(" ") }
  used = used.to_a.sort
  STDERR.puts "These input phones lie outside mcasr/phones.txt:"
  STDERR.puts ($phones + used) - $phones
  # Use the result of this as the keys for the hash Restrict, below.
  # Manually choose the hash's values (each key's replacement, from mcasr/phones.txt).
  exit 0
end

# Uzbek.
$restrict = Hash[ "d̪","d",   "q","k",  "t̪","t",  "ɒ","a",  "ɨː","iː",  "ɸ","f",  "ʁ","r",  "χ","h" ] # Unicode χ, not US-ASCII x!

# Russian.  _j is palatalized, z_ is rhotic.  Multiple phones on the output ("t s") work just fine.
$restrict.merge! Hash[
"bʲ","b",
"dʲ","d",
"fʲ","f",
"kʲ","k",
"lʲ","l",
"mʲ","m",
"nʲ","n",
"pʲ","p",
"rʲ","r",
"sʲ","s",
"tʲ","t",
"vʲ","v",
"zʲ","z",
"ts","t s",
"tɕ","t ɕ",
"ɕɕ","ɕ ɕ",
"ʐ","z"
]

$p = $phoneSeqs.map {|str| str.split(" ").map {|p| r=$restrict[p]; r ? r : p}}
STDERR.puts "Phones restricted."

$tmpPhones = "/tmp/phones-for-bigram.txt"
$tmpLM = "/tmp/bigram.lm"
File.open($tmpPhones, 'w') {|f| $p.each {|line| f.puts line.join " "}}
STDERR.puts "Built ngram-count's input."

`/r/lorelei/kaldi/tools/srilm/bin/i686-m64/ngram-count -order 2 -text #$tmpPhones -lm #$tmpLM`
STDERR.puts "Built LM."

$fst = "bigram.fst"
`cat #$tmpLM | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' \
| /r/lorelei/kaldi/src/bin/arpa2fst - | fstprint | sed -e 's/<s>/<eps>/g' -e 's/<.s>/<eps>/g' \
| tee /tmp/x | fstcompile --isymbols=#$phoneFile --osymbols=#$phoneFile --keep_isymbols --keep_osymbols > #$fst`
STDERR.puts "Built LM FST #$fst."
