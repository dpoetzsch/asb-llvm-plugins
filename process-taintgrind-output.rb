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
    @successor = nil
  end
  
  def is_source?
    return @preds.empty?
  end
  
  def is_tmp_var?
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
    lines = self.get_src_lines()
    
    line = lines[0]
    line = line.red if self.is_sink and not line.nil?
    
    s = "#@func (#@file:#@lineno):  #{line}"
    s += " (found #{lines.length} matching files)" if lines.length > 1
    return s
  end
  
  def get_sources
    # we can't use recursion here because the graph can be VERY huge and the
    # stack depth is just not enough for that
    sources = []
    stack = [self]
    visited = Set.new
    
    while not stack.empty?
      op = stack.pop
      
      next if visited.include? op
      visited.add op
      
      if op.is_source?
        sources.push((not block_given? or yield op) ? op : op.successor)
      else
        successor = (op.successor.nil? or not block_given? or yield op) ? op : op.successor
        op.preds.each { |p| p.successor = successor } # link from where we found this one
        stack.concat op.preds
      end
    end
    
    return sources
  end
  
  @@sources_no_tmp = lambda { |op| ((not op.is_tmp_var?) or op.is_sink) and (not block_given? or yield op) }
  @@sources_no_lib = lambda { |op| not op.get_src_lines.empty? }
  
  def self.sources_no_tmp
    return @@sources_no_tmp
  end
  
  def self.sources_no_lib
    return @@sources_no_lib
  end
  
  def self.new_sources_unique_traces
    locs = Set.new
    return lambda { |op|
      loc = [op.file, op.lineno]
      incl = locs.include?(loc)
      locs.add(loc) if not incl
      not incl
    }
  end
  
  def get_trace_to_sink
    trace = []
    cur = self
    
    while not cur.nil?
      trace.push cur
      cur = cur.successor
    end
    
    return trace
  end
  
  attr_reader :func, :file, :lineno, :var, :from, :preds, :is_sink, :line
  attr_accessor :successor
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
  unique_traces_proc = TaintGrindOp.new_sources_unique_traces
  sources = sink.get_sources { |op| unique_traces_proc.call(op) and TaintGrindOp.sources_no_tmp.call(op) and TaintGrindOp.sources_no_lib.call(op) }
  
  sources.each do |src|
    puts ">>>> The evil cast should occur just before that <<<<"
    puts src.get_trace_to_sink
    puts "="*60
  end
end
