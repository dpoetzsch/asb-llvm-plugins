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

def is_pointer_cast_line?(line)
  return (not line.nil? and line =~ /\(.+?\)/) # check if there is a cast-like thing somewhere
end

allfiles = Dir["**/*"]

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

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.\w+)/
    totalcasts += 1
  
    isice = line.include?("constant")
    if isice
      icecasts += 1
    end
    
    if not noconst or not isice
      puts line

      if $showval > 0
        l = $1.to_i - 1
        files = allfiles.find_all { |f| File.basename(f) == $2 }
        
        if files.empty?
          puts "File not found"
        elsif files.length == 1
          flines = File.read(files[0]).split("\n")
          put_ptr_cast(flines, l)
        else
          puts "Found  #{files.length} files; guessing correct one"
          
          files.each do |file|
            flines = File.read(file).split("\n")
            
            if is_pointer_cast_line?(flines[l])
              put_ptr_cast(flines, l)
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
