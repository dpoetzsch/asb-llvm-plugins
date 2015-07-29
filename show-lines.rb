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

files = Dir["**/*"]

showval = 1
noconst = false

loop do
  case ARGV[0]
  when "-show" 
    ARGV.shift
    showval = ARGV.shift.to_i
  when "-noconst"
    ARGV.shift
    noconst = true
  else
    break
  end
end

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.\w+)/
    if not noconst or not line.include?("constant")
      puts line

      if showval > 0
        file = files.find { |f| f.end_with? $2 }
        l = $1.to_i - 1
        flines = File.read(file).split("\n")
      
        puts flines[l-(showval-1)..l-1]
        puts flines[l].yellow
        puts flines[l+1..l+showval-1] 
      end
      puts
    end
  end
end
