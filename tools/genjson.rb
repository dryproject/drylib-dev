#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'pathname'

SOURCE_DIR = Pathname('source/drylib')

def pluralize_symbol_type(symbol_type)
  case symbol_type
    when :module   then :modules
    when :type     then :types
    when :constant then :constants
    when :function then :functions
    when :alias    then :aliases
    else raise "unknown symbol type #{symbol_type}"
  end
end

def determine_symbol_type(symbol_name)
  return :alias if SOURCE_DIR.join("#{symbol_name}.dry").symlink?
  case symbol_name
    when "math/e", "math/i", "math/pi" then :constant
    when "text/ascii/string", "text/utf8/string" then :type
    else case
      when symbol_name.end_with?("?") then :function
      when symbol_name.start_with?("ffi/libc/") then :function
      when symbol_name.start_with?("logic/") then :function
      when symbol_name.start_with?("math/") then :function
      when symbol_name.start_with?("text/printf/") then :function
      when symbol_name.start_with?("text/ascii/") then :function
      when symbol_name.start_with?("text/utf8/") then :function
      else :type
    end
  end
end

def module_names
  prefix_len = SOURCE_DIR.to_s.size + 1
  suffix_len = '/.drymodule'.size
  Dir[SOURCE_DIR.join('**/.drymodule')].map { |p| p[prefix_len...-suffix_len] }.sort
end

def module_path(module_name)
  Pathname(module_name)
end

def path_to_name(path)
  suffix_len = '.dry'.size
  path.to_s[0...-suffix_len]
end

def link_to(type, name)
  name = name.gsub('?', '%3F')
  case type
    when :module then "https://drylib.org/#{name}/"
    else "https://drylib.org/#{name}.html"
  end
end

def symbol_names(module_name)
  result = Dir[SOURCE_DIR.join(module_name, '*.dry')].map do |f|
    symbol_path = Pathname(f).relative_path_from(SOURCE_DIR)
    symbol_name = path_to_name(symbol_path)
    [symbol_name, symbol_path]
  end
  result.sort_by! do |symbol_name, _|
    symbol_name.scan(/[^\d\.]+|[\d\.]+/).collect { |f| f.match(/\d+(\.\d+)?/) ? f.to_f : f }
  end
end

def language_metadata()
  result = {}
  JSON.parse(File.read('targets.json')).each do |suffix, metadata|
    metadata.each do |name, title|
      result[name.to_sym] = {:name => name, :suffix => suffix, :title => title}
    end
  end
  result
end

def parse_definition(path)
  docstring = File.read(SOURCE_DIR.join(path)).split('"' * 80 + "\n")[1]
  {
    :summary     => (docstring.split("\n").first rescue nil),
    :description => docstring,
    #:see_also    => [], # TODO
  }
end

def get_alias_target(alias_path)
  path_to_name(alias_path.dirname.join(SOURCE_DIR.join(alias_path).readlink))
end

output = {
  :version   => nil,
  # Targets:
  :languages => {},
  # Names:
  :symbols   => {}, # Index
  # Namespaces:
  :modules   => {},
  # Types:
  :types     => {},
  # Terms:
  :constants => {}, # Constants
  :functions => {}, # Functions
  :aliases   => {}, # Aliases
}

# Add target language entries:
language_metadata.each do |language_id, language|
  output[:languages][language_id] = language
end

module_names.each do |module_name|
  output[:symbols][module_name] = :module

  module_path = module_path(module_name)
  module_info = {
    :type      => :module,
    :name      => module_name,
    :path      => module_path,
    :url       => link_to(:module, module_name),
    :modules   => [],
    :types     => [],
    :constants => [],
    :functions => [],
    :aliases   => [],
  }
  module_info.merge!(parse_definition(module_path.join('.drymodule')))

  symbol_names(module_name).each do |symbol_name, symbol_path|
    symbol_type = determine_symbol_type(symbol_name)
    output[:symbols][symbol_name] = symbol_type

    symbol_info = {
      :type    => symbol_type,
      :name    => symbol_name,
      :path    => symbol_path,
      :url     => link_to(:symbol, symbol_name),
      :aliases => [],
    }
    symbol_info[:target] = get_alias_target(symbol_path) if symbol_type == :alias
    symbol_info.merge!(parse_definition(symbol_path))

    symbol_type_key = pluralize_symbol_type(symbol_type)
    output[symbol_type_key][symbol_name] = symbol_info
    module_info[symbol_type_key] << symbol_name
  end

  output[:modules][module_name] = module_info
end

# Hook up the module hierarchy:
output[:modules].each do |module_name, module_info|
  next unless module_name.include?('/')
  parent_module_name = module_name.split('/')[0...-1].join('/')
  output[:modules][parent_module_name][:modules] << module_name
end

# Create backlinks for aliases:
output[:aliases].each do |alias_name, alias_info|
  alias_target = alias_info[:target]
  target_type  = output[:symbols][alias_target]
  target_type_key = pluralize_symbol_type(target_type)
  output[target_type_key][alias_target][:aliases] << alias_name
end

# Prune the tree a bit:
%w(modules types constants functions aliases languages).each do |symbol_type_key|
  output[symbol_type_key.to_sym].each do |symbol_name, symbol_info|
    symbol_info.reject! { |k, v| v.is_a?(Array) && v.empty? }
  end
end

# Pretty-print the JSON output:
puts JSON.pretty_generate(output)
