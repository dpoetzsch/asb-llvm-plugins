#!/usr/bin/env ruby

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end

  def light_blue
    colorize(36)
  end
end

files = Dir["**/*.c"]

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.c)/
    #puts "#$2 line #$1"
    puts line

    file = files.find { |f| f.end_with? $2 }
    l = $1.to_i - 1
    flines = File.read(file).split("\n")
    puts flines[l-3..l-1]
    puts flines[l].yellow
    puts flines[l+1..l+3]
    puts
  end
end
