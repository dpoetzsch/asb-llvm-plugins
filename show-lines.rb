#!/usr/bin/env ruby

require_relative "colored_str.rb"
require_relative "util.rb"


$showval = 1
noconst = false

def put_ptr_cast(flines, l)
  puts flines[l-($showval-1)..l-1]
  puts flines[l].yellow
  puts flines[l+1..l+$showval-1] 
end

loop do
  case ARGV[0]
  when "-show" 
    ARGV.shift
    $showval = ARGV.shift.to_i
  when "-noconst"
    ARGV.shift
    noconst = true
  else
    break
  end
end

totalcasts = 0
icecasts = 0

cast_lines = {}

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.\w+)/
    lineno = $1.to_i - 1
    filename = $2
    
    while filename =~ /^\.\.?\/(.+)/
      filename = $1
    end
    
    if cast_lines.has_key? filename
      cast_lines[filename][lineno] = line
    else
      cast_lines[filename] = {lineno => line}
    end
  end
end

cast_lines.each do |filename, lines|
  # pre-filter the files for this filename
  files = guess_path(filename)
  
  lines.each do |lineno, msg|
    totalcasts += 1
    isice = msg.include?("constant")
    if isice
      icecasts += 1
    end
    
    if not noconst or not isice
      puts msg

      if $showval > 0
        if files.empty?
          puts "File not found"
        elsif files.length == 1
          flines = File.read(files[0]).split("\n")
          put_ptr_cast(flines, lineno)
        else
          puts "Found  #{files.length} files; guessing correct one"
          
          files.each do |file|
            flines = File.read(file).split("\n")
            
            if is_pointer_cast_line?(flines[lineno])
              put_ptr_cast(flines, lineno)
            end
          end
        end
        
      end
      puts
    end
  end
end

puts "-------------------------------------------------------------------------"
puts "Total casts: #{totalcasts} (#{icecasts} casts of integer constant expressions)"
