#!/usr/bin/env ruby

ALL_FILES = Dir["**/*"]

def guess_path(filename, allfiles=ALL_FILES)
  return allfiles.find_all { |f| f.end_with?(filename) and File.basename(f) == File.basename(filename) }
end

def is_pointer_cast_line?(line, colstart)
  return (not line.nil? and line[colstart..-1] =~ /^\(.+?\)\s*.+$/) # check if there is a cast-like thing starting at colstart
end
