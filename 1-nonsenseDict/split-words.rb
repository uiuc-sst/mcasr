#!/usr/bin/env ruby

# Input:  one word per line.
# Output: one word per line, split via Tex's hyphenation rules, duplicates removed.
# Extra output: dict_subwords.txt, one subword per line, duplicates removed.
#
# Hyphenates 250K words per minute.
# Splitting into subwords is much slower, 4K wpm.  C++ would be better for this.

# Usage: ./split-words.rb < dict_words.txt > dict_words2.txt
# Usage: ./get-words.sh < dict_grapheme.txt | ./split-words.rb > dict_words2.txt

Len=1500
wordsIn = ""
$out = []
ARGF.readlines.map(&:chomp).each {|word|
  sNext = wordsIn + " " + word
  # 0.8 avoids the last word output by tex being wrongly preceded by a space, when it should be a hyphen.
  if sNext.size < Len * 0.8
    # Accumulate words until they're too long.
    wordsIn = sNext
  else

    # Send the words to tex.
    #
    # Instead of calling tex, it would be simpler to call
    # rubygems.org/gems/text-hyphen/versions/1.4.1 or
    # www.nedbatchelder.com/code/modules/hyphenate.py,
    # but those might not import many non-English hyphenation rules.
    wordsOut = `export max_print_line=#{Len}; echo "\\showhyphens{#{wordsIn}}" | tex | tail -n +4 | head -n -10`

    # Filter out warnings reported by tex.
    wordsOut.gsub! /Loose \\hbox \(badness \d+\) detected at line 0/, ""
    wordsOut.gsub! /Underfull \\hbox \(badness \d+\) detected at line 0/, ""
    wordsOut.gsub! /Missing character\: There is no \^\^.. in font cmr10\!/, ""
    wordsOut.gsub! '[]', ""
    wordsOut.gsub! '\tenrm', ""
    if !wordsOut
      STDERR.puts "#$0: ignoring unexpectedly empty output from input #{wordsIn}; raw output was: {"
      STDERR.puts `export max_print_line=#{Len}; echo "\\showhyphens{#{wordsIn}}" | tex | tail -n +4 | head -n -10`
      STDERR.puts "}"
    else
      wordsOut = wordsOut.split
      if false
	# For debugging, verify the hyphenation.
	puts wordsIn; puts wordsOut.join(' '); puts
      end
      $out += wordsOut
      # STDERR.puts "#$0: hyphenated #{$out.size} words..."
    end

    # Start a fresh batch of words.
    wordsIn = word
  end
}
`rm texput.log` # Clean up tex's temporary files.
STDERR.puts "#$0: de-duplicating hyphenated words."
$out = $out.sort.uniq
puts $out
#puts "\n"
STDERR.puts "#$0: wrote hyphenated words."

# Output just the subwords, 2 or more letters, duplicates removed.
# (When fusing short subwords, keep the not-too-short ones too.)
SubwordLenMin = 2
$subs = []
$out.each {|w|
  # w == "aa-man-varghan-chahi-waqt"
  $wsubs = w.split '-'
  $wsubs0 = w.split '-' # deep copy, haha
  while true
    lens = $wsubs.map {|s| s.size}
    iShortest = lens.index(lens.min)
    break if $wsubs.size <= 1 || lens[iShortest] >= SubwordLenMin

    # The shortest subword is too short, so fuse it with its shorter neighbor.
    if iShortest == 0
      iFuse = iShortest+1
    elsif iShortest == lens.size - 1
      iFuse = iShortest-1
    else
      lenPrev = lens[iShortest-1]
      lenNext = lens[iShortest+1]
      iFuse = lenPrev < lenNext ? iShortest-1 : iShortest+1
    end
    iShortest,iFuse = [iShortest,iFuse].minmax # Sort them.
    # STDERR.puts "#$0: internal error." if iShortest+1 != iFuse
    # Fuse iShortest with its successor.
    subsNew = []
    $wsubs.each_with_index {|s,i|
      if i == iShortest
	subsNew << s + $wsubs[i+1]
      elsif i == iShortest+1
	# Skip this subword.
      else
	subsNew << s
      end
    }
    # STDERR.puts "  #{$wsubs} -> #{subsNew}"
    $wsubs = subsNew
  end
  # Include not-yet-fused subwords, as long as they're long enough.
  subsFresh = ($wsubs + $wsubs0.delete_if {|s| s.size < SubwordLenMin}).sort.uniq
  $subs += subsFresh
  # STDERR.puts subsFresh
}

File.open("dict_subwords.txt", "w") {|f|
  $subs.sort.uniq.each {|s| f.puts s}
}
