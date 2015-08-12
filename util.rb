#!/usr/bin/env ruby

ALL_FILES = Dir["**/*"]

def guess_path(filename, allfiles=ALL_FILES)
  return allfiles.find_all { |f| f.end_with?(filename) and File.basename(f) == File.basename(filename) }
end
