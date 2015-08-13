#!/usr/bin/env ruby
require_relative"util.rb"


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

def rewrite_source(filename, line)
  file = File.read(filename).split("\n") 
  linenumber= line.to_i
  tmpname=get_new_name
  if file[linenumber]=~/(.+) \(([A-Za-z0-9_]+)\) ([A-Za-z0-9_]+)(.+)/
    file[linenumber]=$1 + " " + tmpname + $4
    type = $2
    varname= $3
    puts "found cast in #{filename} line #{line}, #{varname} is cast to #{type}"
  else
    puts "Can't find the cast" 
    return nil
  end
  file.insert(linenumber,"#{type} #{tmpname} = #{type} #{varname};")
  file.insert(linenumber+1, "TNT_MAKE_MEM_TAINTED(&#{tmpname},sizeof(#{tmpname}));")
  File.open(filename, "w") {|f| f.write(file.join("\n"))}
end

def add_header(filename)
  file = File.read(filename).split("\n")
  header_included=0
  file.each do |line|
    if line == "#include \"taintgrind.h\""
      header_included=1
      break
    end
  end
  if header_included == 0
    puts "no taingrind header"
    file.insert(0,"#include \"taintgrind.h\"")
    File.open(filename, "w") {|f| f.write(file.join("\n"))}
  end
end

cast_lines = {}

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.\w+)/
    lineno = $1.to_i - 1
    filename = $2
    
    while filename =~ /^\.\.?\/(.+)/ #cuts the ../../filename.c to filename.c
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
  files = guess_path(filename)
  lines.each do |lineno,msg|
   
    if files.empty?
      puts "file #{filename} not found"
      return nil
    elsif files.length>1
      puts "found #{files.length} files; guessing correct one"
      files.each do |file|
        flines=File.read(file).split("\n")
        if is_pointer_cast_line?(flines[lineno]) #We use the first file including a cast
          files[0]=file
        end
      end
    end
    rewrite_source(files[0],lineno)
  end
  
  add_header(files[0])
end 




