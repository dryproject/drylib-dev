#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'pathname'

SOURCE_DIR = Pathname('source/drylib')
SPHINX_DIR = Pathname('sites/drylib.org')
YASHA_FILE = Pathname('/tmp/yasha.json')

def pluralize_symbol_type(symbol_type)
  case symbol_type.to_sym
    when :module   then :modules
    when :type     then :types
    when :constant then :constants
    when :function then :functions
    when :alias    then :aliases
    else raise "unknown symbol type #{symbol_type}"
  end
end

abort "usage: #{$0} input.json" if ARGV.empty?

input = JSON.parse(File.read(ARGV.first))
input['symbols'].each do |symbol_name, symbol_type|
  #next unless %w(constant).include?(symbol_type)

  symbol_type_key = pluralize_symbol_type(symbol_type).to_s
  symbol_info = input[symbol_type_key][symbol_name].merge({:symbols => []})

  %w(modules types constants functions aliases).each do |symbol_type_key|
    next unless symbol_info.has_key?(symbol_type_key)
    symbol_info[:symbols] += symbol_info[symbol_type_key] unless symbol_type_key == 'modules'
    symbol_info[symbol_type_key] = Hash[symbol_info[symbol_type_key].map { |k| [k, input[symbol_type_key][k]] }]
  end
  symbol_info[:symbols].sort_by! do |symbol_name|
    symbol_name.scan(/[^\d\.]+|[\d\.]+/).collect { |f| f.match(/\d+(\.\d+)?/) ? f.to_f : f }
  end

  j2_template = SPHINX_DIR.join('.templates', symbol_type + '.rst.j2')
  next unless j2_template.exist?

  rst_document = case symbol_type.to_sym
    when :module then [symbol_name, 'index.rst'].join('/')
    else "#{symbol_name}.rst"
  end
  rst_document = SPHINX_DIR.join(rst_document)

  File.write(YASHA_FILE, JSON.pretty_generate(symbol_info) + "\n")
  yasha_cmd = "yasha --mode=pedantic --keep-trailing-newline -v #{YASHA_FILE} -o #{rst_document} #{j2_template}"
  puts yasha_cmd
  FileUtils.mkdir_p rst_document.dirname
  `#{yasha_cmd}`
end
