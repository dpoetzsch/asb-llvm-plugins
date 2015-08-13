#!/usr/bin/env ruby

require_relative "util.rb"
require_relative "colored_str.rb"

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

def rewrite_source(filename, linenumber, colno)
  lines = File.read(filename).split("\n")
  tmpname=get_new_name
  
  prefix = lines[linenumber][0...colno]
  
  if lines[linenumber][colno..-1] =~ /^\(([A-Za-z0-9_]+)\) ([A-Za-z0-9_]+)(.+)/
    lines[linenumber]= prefix + " " + tmpname + $3
    type = $1
    varname= $2
    cast = "(#{type}) #{varname}"
    puts "Found cast in #{filename} at #{linenumber}:#{colno}: #{cast.red}; Replacing:"
    
    lines.insert(linenumber,"#{type} #{tmpname} = (#{type}) #{varname};")
    lines.insert(linenumber+1, "TNT_MAKE_MEM_TAINTED(&#{tmpname}, sizeof(#{tmpname}));")
    
    puts lines[linenumber..linenumber+2]
    puts 
    File.open(filename, "w") {|f| f.write(lines.join("\n"))}
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
    File.open(filename, "w") {|f| f.write(lines.join("\n"))}
  end
end

cast_lines = {}

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):(\d+).+?in file: (.+\.\w+)/
    lineno = $1.to_i - 1
    colno = $2.to_i - 1
    filename = $3
    
    while filename =~ /^\.\.?\/(.+)/ #cuts the ../../filename.c to filename.c
      filename = $1
    end
    
    if cast_lines.has_key? filename
      cast_lines[filename][[lineno, colno]] = line
    else
      cast_lines[filename] = {[lineno, colno] => line}
    end
  end
end

cast_lines.each do |filename, lines|
  files = guess_path(filename)
  lines.each do |linecol,msg|
    lineno, colno = linecol
    if files.empty?
      puts "file #{filename} not found"
      return nil
    else
      puts "found #{files.length} files; guessing correct one"
      files.each do |file|
        flines=File.read(file).split("\n")
        if is_pointer_cast_line?(flines[lineno]) #We use the first file including a cast
          rewrite_source(file,lineno, colno)
          break
        end
      end
    end
  end
  
  add_header(files[0])
  
  puts "="*80
end 




