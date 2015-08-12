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

def find_cast_var(line)
  if line =~ /(.+) \(int\) (\w+)(.+)/
    return $2
  else 
    puts "Can't find cast var"
    return nil
  end
end

def rewrite_source(filename, line)
  file = File.read(filename).split("\n") 
  linenumber= line.to_i
  varname=find_cast_var(file[linenumber])
  puts "var is #{varname}"
  tmpname=get_new_name
  if file[linenumber]=~/(.+) \(int\) (\w+)(.+)/
    file[linenumber]=$1 + " " + tmpname + $3
  else 
    return nil
  end
  file.insert(linenumber,"int #{tmpname} = (int) #{varname};")
  file.insert(linenumber+1, "TNT_MAKE_MEM_TAINTED(&#{tmpname},sizeof(#{tmpname}));")
  if file[0] != "#include \"taintgrind.h\""
    file.insert(0,"#include \"taintgrind.h\"")
  end
  File.open(filename+".castfix", "w") {|f| f.write(file.join("\n"))}
  
end

ARGF.read.split("\n").each do |line|
  if line =~ /cast at\s?(\d+):.+in file: (.+\.\w+)/
    lineno = $1.to_i - 1
    filename = $2
    
    while filename =~ /^\.\.?\/(.+)/ #cuts the ../../filename.c to filename.c
      filename = $1
    end
    
    files = guess_path(filename)
    if files.empty?
      puts "file #{filename} not found"
      return nil
    elsif files.length>1
      puts "found #{files.length} files; guessing correct one"
      files.each do |file|
        flines=File.read(file).split("\n")
        if is_pointer_cast_line?(flines,lineno)
          files[0]=file
        end
      end
    end
      
    rewrite_source(files[0],lineno)
  end 
end    














