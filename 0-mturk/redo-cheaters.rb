#!/usr/bin/env ruby

# From a downloaded set of HITs, extract those that need redoing because
# they were submitted by blocked (cheating or lazy) turkers.

if ARGV.size != 2
  STDERR.puts "Usage: #$0 batchCorrupted.csv batchRedoThese.csv"
  exit 1
end

cheaters = %w(A11NUW5OVADGYU A2IYMT4S5WT96I A2MPQFN5X7R4U5 A3HDMR3ZFQVT7B A3UPV16IECELHV AS7WICVB6Y8ZQ AZI3ZRQVVFWJQ)

first = true
require "csv"
CSV.open(ARGV[1], "w") {|w|
  CSV.foreach(ARGV[0], "r") {|r|
    if first
      w << r
      first = false
      next
    end
    w << r if cheaters.include? r[15]
  }
}
