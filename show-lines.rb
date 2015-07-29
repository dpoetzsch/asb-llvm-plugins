#!/usr/bin/env ruby

files = Dir["**/*.c"]

File.read(ARGV[0]).split("\n").each do |line|
  if line =~ /cast at(\d+):.+in file: (.+\.c)/
    #puts "#$2 line #$1"
    puts line

    file = files.find { |f| f.end_with? $2 }
    l = $1.to_i
    puts File.read(file).split("\n")[l-3..l+3]
    puts
  end
end
