#!/usr/bin/env ruby
# encoding: utf-8

# Make a bigram LM from the phone sequences in Wenda's prondict.
# On stdin, expects e.g.
#   prondict_uzbek-from-wenda.txt
#   prondicts/rus-prondict-july26.txt
#   prondicts/Tigrinya/prondict-from-amharic-phones.txt
# where each line is:  word, tab-or-space, space-delimited IPA phones.

# Read the prondict.
# For each line, discard the word and keep the phone sequence.
# Discard truncated phone sequences (ABORT).
# Remove Tigrinya punctuation from phone sequences ([preface_colon], [phrase], etc.)
$phoneSeqs = ARGF.readlines.map {|l| l.chomp} \
  .map {|l| l.sub(/[^\s]*\s/, '').strip} \
  .delete_if {|l| l =~ / ABORT$/} \
  .map {|l| l.gsub /\[[a-z_]*\]/, ''}

$phoneFile="/r/lorelei/PTgen/mcasr/phones.txt"
$phones = File.readlines($phoneFile) .map {|l| l.split[0]} .sort
STDERR.puts "Phones parsed."

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
"ʐ","z",
]

# Tigrinya, using Amharic phones.  _h is aspirated.
$restrict.merge! Hash[
"eː","e",
"pʰ","p h",
"q","k",
# "ts","t s",
"tʃʰ","t ʃ",
"tʰ","t", # Or "t h".  Too close to "earball"; see how it affects the end result.
"p'","p",
"q","k",
"t'","t",
"ts'","t s",
"tʃ'","t ʃ",
"ħ","h",
"ʷa","a",
"ʷe","e",
"ʷi","i",
"ʷə","ə",
"ʷɨ","ɨ",
]

# Oromo.
$restrict.merge! Hash[
"ai","a i",
"au","a u",
"ɑi","ɑ i",
"ɑu","ɑ u",
"ɔu","ɔ u",
"ɛi","ɛ i",
"ɞi","ɝ i",
"ɞu","ɝ u",
"ɢ","k", # uvular plosive
"ʕ"," ",
# "χ","h"
]

def restrict(ph) r=$restrict[ph]; r ? r : ph end

if false
  require 'set'
  used = Set.new
  $phoneSeqs.sort.uniq.each {|s| used.merge s.split(" ") }
  used = used.to_a.sort
  missing = ($phones + used) - $phones
  if missing.empty?
    puts "All input phones are found in mcasr/phones.txt.  Good."
  else
    puts "These input phones lie outside mcasr/phones.txt:"
    puts missing.inspect
  end
  # Restrict the phones in "used", and split multiple phones apart (split and flatten).
  used = used.map {|ph| restrict(ph).split(/\s/)} .flatten
  missing = ($phones + used) - $phones
  if missing.empty?
    puts "After restricting, all input phones are found in mcasr/phones.txt.  Good."
  else
    puts "After restricting, these input phones lie outside mcasr/phones.txt:"
    puts missing.inspect
  end
  # Use the result of this as the keys for the hash $restrict.
  # Manually choose the hash's values (each key's replacement, from mcasr/phones.txt).
  exit 0
end

$p = $phoneSeqs.map {|str| str.split(" ").map {|p| restrict(p)}}
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
