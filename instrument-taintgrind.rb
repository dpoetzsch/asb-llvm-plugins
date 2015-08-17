#!/usr/bin/env ruby

require_relative "util.rb"
require_relative "colored_str.rb"

$dryrun = false
$count=0

def get_new_name ()
  tmp_name="tmp#{$count}"
  $count+=1
  return tmp_name
end

def read_line(filename,linenumber)
  found_line = nil
  lineno=0
  File.foreach(filename) do |line|
    if lineno == linenumber 
      found_line = line.chomp
      break
    else
      lineno+=1
    end
  end
  return found_line
end

def find_cast_var(line) #Not used, except for debugging
  if line =~ /(.+) \(([A-Za-z0-9_]+)\) (\w+)(.+)/
    return $3
  else 
    puts "Can't find cast var"
    return nil
  end
end

def rewrite_source(filename, linenumber, colstart, last_token_start)
  lines = File.read(filename).split("\n")
  tmpname=get_new_name
  
  prefix = lines[linenumber][0...colstart]
  puts "prefix = " + prefix
  infix = lines[linenumber][colstart..last_token_start]
  puts "infix = " + infix
  suffix = lines[linenumber][last_token_start+1..-1]
  puts "suffix = " + suffix
  
  if not (infix[-1] == "]" or infix[-1] == ")")
    if suffix=~/^([A-Za-z0-9_]+)(.+)$/
       infix += $1
       suffix = $2
    end
  end  
  if infix =~ /^\(([A-Za-z0-9_]+)\)\s*(.+)$/
    lines[linenumber]= prefix + " " + tmpname + suffix
    type = $1
    varname= $2
    cast = "(#{type}) #{varname}"
    puts "Found cast in #{filename} at #{linenumber}:#{colstart}: #{cast.red}; Replacing:".green
    
    lines.insert(linenumber,"#{type} #{tmpname} = (#{type}) #{varname};")
    lines.insert(linenumber+1, "TNT_MAKE_MEM_TAINTED(&#{tmpname}, sizeof(#{tmpname}));")
    
    puts lines[linenumber..linenumber+2]
    puts 
    File.open(filename, "w") {|f| f.write(lines.join("\n") + "\n") } if not $dryrun
  else
    puts "Can't find the cast"
  end
end

def add_header(filename)
  lines = File.read(filename).split("\n")
  header_included=0
  lines.each do |line|
    if line == "#include \"taintgrind.h\""
      header_included=1
      break
    end
  end
  if header_included == 0
    puts "adding #include \"taintgrind.h\""
    lines.insert(0,"#include \"taintgrind.h\"")
    File.open(filename+"new", "w") {|f| f.write(lines.join("\n"))}
  end
end

cast_lines = {}
cnt = 0

# process cli arguments
loop do
  case ARGV[0]
  when "-dryrun"
    $dryrun = true
    ARGV.shift
  else
    break
  end
end

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):(\d+)-(\d+).+?in file: (.+\.\w+)/
    cnt += 1
    lineno = $1.to_i - 1
    colstart = $2.to_i - 1
    last_token_start= $3.to_i - 1
    filename = $4
    
    while filename =~ /^\.\.?\/(.+)/ #cuts the ../../filename.c to filename.c
      filename = $1
    end
    
    if cast_lines.has_key? filename
      cast_lines[filename][[lineno, colstart, last_token_start]] = line
    else
      cast_lines[filename] = {[lineno, colstart, last_token_start] => line}
    end
  end
end

puts "Found #{cnt} casts"

cast_lines.each do |filename, lines|
  lines = lines.keys.sort.reverse 
  files = guess_path(filename) 
  puts files
  puts "m1"
  lines.each do |linecol|
    puts "m2"
    puts linecol
    lineno, colstart, last_token_start = linecol
    if files.empty?
      puts "File #{filename} not found"
    else
      puts "Found #{files.length} files; guessing correct one" 
      files.each do |file|
        flines=File.read(file).split("\n")
        if is_pointer_cast_line?(flines[lineno], colstart) #We use the first file including a cast
          rewrite_source(file,lineno, colstart, last_token_start)
          break
        end
      end
    end
  end
  
  add_header(files[0])
  
  puts "="*80
end 




