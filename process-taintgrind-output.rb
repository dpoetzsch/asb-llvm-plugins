#!/usr/bin/env ruby

require "set"
require_relative "colored_str.rb"
require_relative "util.rb"

class TaintGrindOp
  def self.is_taintgrindop_line?(line)
    return line.split(" | ").length == 5
  end
  
  def initialize(line)
    @line = line
    @is_sink = false
  
    elems = line.split(" | ")
    if elems[0] =~ /0x\w+: (.+?) \((.+):(\d+)\)/  # e.g. 0x40080D: main (two-taints.c:10)
      @func = $1
      @file = $2
      @lineno = $3.to_i
    end
    
    if elems[4] =~ /^(.+?) <- (.+?)$/ # e.g. t54_1741 <- t42_1773, t29_4179
      @var = $1
      @from = $2.split(", ")
    elsif elems[4] =~ /^(.+?) <\*- (.+?)$/ # e.g. t78_744 <*- t72_268
      @var = $1
      @from = $2.split(", ")
      @is_sink = true
    else  # e.g. t54_1741
      @var = elems[4]
      @from = []
    end
    
    if elems[1].start_with? "IF "
      @is_sink = true
    end
    
    @preds = []
  end
  
  def is_tmp_var
    return @var =~ /^t\d+_\d+$/
  end
  
  def is_use?
    return @from.empty?
  end
  
  def is_def?
    return (not self.is_use?)
  end
  
  def get_src_lines
    return guess_path(@file).map { |f| File.read(f).split("\n")[@lineno-1] }.find_all { |l| not l.nil? }
  end

  def to_s
    puts
    puts @line
    lines = self.get_src_lines()
    
    line = lines[0]
    line = line.red if self.is_sink and not line.nil?
    
    s = "#@func (#@file:#@lineno):  #{line}"
    s += " (found #{lines.length} matching files)" if lines.length > 1
    return s
  end
  
  def get_full_path
    # we can't use recursion here because the graph can be VERY huge and the
    # stack depth is just not enough for that
    path = []
    stack = [self]
    processed = Set.new
    
    while not stack.empty?
      op = stack.pop
      next if processed.include? op
      processed.add op
      
      path.push(op) if not block_given? or yield op
      stack.concat op.preds
    end
    
    return path.reverse
  end
  
  def get_path
    return get_full_path { |op| (op.is_sink or not op.is_tmp_var) and (not block_given? or yield op) }
  end
  
  def get_path_unique
    locs = Set.new
    return get_full_path { |op|
      loc = [op.file, op.lineno]
      ret = locs.include?loc
      locs.add loc
      p loc if not ret
      not ret
    }
  end
  
  def get_path_no_lib
    return get_path { |op| not op.get_src_lines.empty? }
  end
  
  attr_reader :func, :file, :lineno, :var, :from, :preds, :is_sink, :line
end

###### CREATE TaintGrindOp GRAPH ##########

# var -> TaintGrindOp
taintgrind_ops = {}
sinks = []

ARGF.read.split("\n").each do |line|
  if not TaintGrindOp.is_taintgrindop_line? line
    next
  end
  
  tgo = TaintGrindOp.new(line)
  
  # link to predecessors
  tgo.from.each do |fromvar|
    if taintgrind_ops.has_key?(fromvar)
      tgo.preds.push(taintgrind_ops[fromvar])
    end
  end
  if tgo.is_use? and taintgrind_ops.has_key? tgo.var
    tgo.preds.push taintgrind_ops[tgo.var]
  end
  
  if tgo.is_def?
    if taintgrind_ops.has_key?(tgo.var)
      puts "ERROR: Duplicated definition"
    end
    taintgrind_ops[tgo.var] = tgo
  end
  
  if tgo.is_sink
    sinks.push tgo
  end
end

sinks.each do |sink|
  puts ">>>> The evil cast should occur just before that <<<<"
  puts sink.get_path
  puts "="*40
  break  # TODO REMOVE THIS
end
