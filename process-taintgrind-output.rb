#!/usr/bin/env ruby

require_relative "colored_str.rb"
require_relative "util.rb"

class TaintGrindOp
  def self.is_taintgrindop_line?(line)
    return line.split(" | ").length == 5
  end
  
  def initialize(line)
    @line = line
  
    elems = line.split(" | ")
    if elems[0] =~ /0x\w+: (\w+) \((.+):(\d+)\)/  # e.g. 0x40080D: main (two-taints.c:10)
      @func = $1
      @file = $2
      @lineno = $3.to_i
    end
    
    if elems[4] =~ /^(.+?) <- (.+?)$/ # e.g. t54_1741 <- t42_1773, t29_4179
      @var = $1
      @from = $2.split(", ")
    else  # e.g. t54_1741
      @var = elems[4]
      @from = []
    end
    
    if elems[1].start_with? "IF "
      @is_sink = true
    else
      @is_sink = false
    end
    
    @preds = []
  end
  
  def is_tmp_var
    return @var =~ /^t\d+_\d+$/
  end

  def to_s
    lines = guess_path(@file).map { |f| File.read(f).split("\n")[@lineno-1] }.find_all { |l| not l.nil? }
    
    line = lines[0]
    line = line.red if self.is_sink
    
    s = "#@func (#@file:#@lineno):  #{line}"
    s += " (found #{lines.length} matching files}" if lines.length > 1
    return s
  end
  
  def get_full_path
    p = @preds.empty? ? [] : @preds.map{|op| op.get_full_path()}.flatten
    return p.push self
  end
  
  def get_path
    p = @preds.empty? ? [] : @preds.map{|op| op.get_path()}.flatten
    p.push self if self.is_sink or not self.is_tmp_var
    return p
  end
  
  attr_reader :func, :file, :lineno, :var, :from, :preds, :is_sink
end

###### CREATE TaintGrindOp GRAPH ##########

# var -> [TaintGrindOp]
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
      tgo.preds.concat(taintgrind_ops[fromvar])
    end
  end
  if taintgrind_ops.has_key? tgo.var
    tgo.preds.concat taintgrind_ops[tgo.var]
  end
  
  if taintgrind_ops.has_key?(tgo.var)
    taintgrind_ops[tgo.var].push(tgo)
  else
    taintgrind_ops[tgo.var] = [tgo]
  end
  
  if tgo.is_sink
    sinks.push tgo
  end
end

sinks.each do |sink|
  puts ">>>> The cast should occur just before that <<<<"
  puts sink.get_path
  puts "="*40
end
