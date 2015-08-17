#!/usr/bin/env ruby

require_relative "util.rb"
require_relative "colored_str.rb"

$dryrun = false
$verbose = false
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

def rewrite_source(filename, lineno, all_cols)
  lines = File.read(filename).split("\n")
  
  lines_before = lines[0...lineno]
  castline = lines[lineno]
  lines_after = lines[lineno+1..-1]
  
  # start by the last cast
  all_cols.sort.reverse.each do |cols|
    colstart, last_token_start = cols
    
    prefix = castline[0...colstart]
    thecast = castline[colstart..last_token_start]
    suffix = castline[last_token_start+1..-1]
    
    if $verbose
      puts "prefix = " + prefix
      puts "cast = " + thecast
      puts "suffix = " + suffix
    end
    
    if not (thecast[-1] == "]" or thecast[-1] == ")")
      if suffix=~/^([A-Za-z0-9_]+)(.+)$/
         thecast += $1
         suffix = $2
      end
    end
    
    if thecast =~ /^\(([A-Za-z0-9_]+)\)\s*(.+)$/
      puts("Found cast in #{filename} at #{lineno}:#{colstart}-#{last_token_start}: ".green + prefix + thecast.red + suffix)
    
      type = $1
      varname= $2
      
      tmpname = get_new_name()
      
      # replace cast line
      castline = prefix + " " + tmpname + " " + suffix
      
      lines_before.push "#{type} #{tmpname} = (#{type}) #{varname};"
      lines_before.push "TNT_MAKE_MEM_TAINTED(&#{tmpname}, sizeof(#{tmpname}));"
      
      puts lines_before[-2..-1]
      puts castline
      puts
    else
      puts "Can't find the cast"
    end
  end
  
  lines = lines_before + [castline] + lines_after
  File.open(filename, "w") {|f| f.write(lines.join("\n") + "\n") } if not $dryrun
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
    puts "Adding #include \"taintgrind.h\"".yellow
    lines.insert(0,"#include \"taintgrind.h\"")
    File.open(filename, "w") {|f| f.write(lines.join("\n"))} if not $dryrun
  end
end

# process cli arguments
loop do
  case ARGV[0]
  when "-dryrun"
    $dryrun = true
    ARGV.shift
  when "-v"
    $verbose = true
    ARGV.shift
  else
    break
  end
end

# {filename => {lineno => [[colstart, last_token_colstart]]} }
cast_lines = {}
cnt = 0

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
    
    if not cast_lines.has_key? filename
      cast_lines[filename] = {}
    end
    if not cast_lines[filename].has_key? lineno
      cast_lines[filename][lineno] = []
    end
    
    cast_lines[filename][lineno].push [colstart, last_token_start]
  end
end

puts "Found #{cnt} casts"

cast_lines.each do |filename, linecols|
  puts "="*80
  
  files = guess_path(filename)
  lines = linecols.keys.sort.reverse
  
  lines.each do |lineno|
    
    if files.empty?
      puts "File #{filename} not found"
    else
      puts "Found #{files.length} files; guessing correct one" if files.length > 1
      
      cols = linecols[lineno] # all [startcol, endcol] pairs of casts in this line
      
      files.each do |file|
        flines=File.read(file).split("\n")
        if is_pointer_cast_line?(flines[lineno], cols[0][0]) #We use the first file including a cast
          rewrite_source(file,lineno, cols)
          break
        end
      end
    end
  end
  
  add_header(files[0])
end 



