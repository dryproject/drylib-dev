#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'pathname'

module DRY
  Language = Struct.new(:id, :name, :title)
  Module   = Struct.new(:dir, :name, :modules, :symbols)
  Symbol   = Struct.new(:file, :name)

  class Symbol
    def description
      @description ||= File.read(self.file).split('"' * 80 + "\n")[1]
    end
  end
end

def parse_language_metadata(json_file)
  result = {}
  JSON.parse(File.read(json_file)).each do |id, metadata|
    metadata.each do |name, title|
      result[id.to_sym] = DRY::Language.new(id.to_sym, name.to_sym, title)
    end
  end
  result
end

def module_names(module_dir)
  prefix_len = module_dir.to_s.size + 1
  suffix_len = '/.drypackage'.size
  Dir["#{module_dir}/**/.drypackage"].map { |p| p[prefix_len...-suffix_len] }.sort
end

def module_tree(module_dir)
  suffix_len = '.dry'.size
  module_names(module_dir).inject({}) do |result, module_name|
    module_ = DRY::Module.new(nil, module_name, [], [])
    prefix_len = module_dir.to_s.size + module_name.size + 2
    Dir["#{module_dir}/#{module_name}/*.dry"].map do |f|
      module_.symbols << DRY::Symbol.new(Pathname(f), f[prefix_len...-suffix_len])
    end
    result[module_name] = module_
    result
  end
end

def create_language_files(sphinx_dir, languages)
  languages.each do |language|
    title = "DRYlib for #{language.title.to_s}"
    stars = '*' * title.size
    text = ".. index:: pair: #{language.title}; language\n\n"
    text << [stars, title, stars].join("\n") + "\n"
    File.write("#{sphinx_dir}/#{language.name}.rst", text)
  end
end

def create_module_dirs(sphinx_dir, module_names)
  module_names.each { |module_name| FileUtils.mkdir_p "#{sphinx_dir}/#{module_name}" }
end

def create_module_indexes(sphinx_dir, module_tree)
  module_tree.values.each do |module_|
    title = module_.name.to_s
    stars = '*' * title.size
    text = ".. index:: module: #{module_.name}\n\n"
    text << [stars, title, stars].join("\n") + "\n"
    text << "\n.. toctree::\n   :maxdepth: 2\n"
    text << "\n" unless module_.symbols.empty?
    module_.symbols.map(&:name).sort.each do |symbol_name|
      text << "   #{symbol_name}\n"
    end
    File.write("#{sphinx_dir}/#{module_.name}/index.rst", text)
  end
end

def create_module_symbols(sphinx_dir, module_tree)
  module_tree.values.each do |module_|
    module_.symbols.each do |symbol|
      symbol_path = [module_.name, symbol.name].join('/')
      title = symbol_path.to_s
      text = ".. index:: pair: #{symbol_path}; type\n\n"
      text << [title, '=' * title.size].join("\n") + "\n"
      unless symbol.description.empty?
        text << "\n" << symbol.description
      end
      File.write("#{sphinx_dir}/#{symbol_path}.rst", text)
    end
  end
end

def write_index_rst(sphinx_dir, module_names)
  file = "#{sphinx_dir}/index.rst"
  text = File.read(file).sub("TREE", "\n   " + module_names.map { |s| "#{s}/index" }.join("\n   ") + "\n")
  File.write(file, text)
end

SOURCE_DIR   = 'source/drylib'
SPHINX_DIR   = 'sites/drylib.org'
LANGUAGES    = parse_language_metadata('targets.json')
MODULE_NAMES = module_names(SOURCE_DIR)
MODULE_TREE  = module_tree(SOURCE_DIR)

create_language_files(SPHINX_DIR, LANGUAGES.values)
create_module_dirs(SPHINX_DIR, MODULE_NAMES)
create_module_indexes(SPHINX_DIR, MODULE_TREE)
create_module_symbols(SPHINX_DIR, MODULE_TREE)
write_index_rst(SPHINX_DIR, MODULE_NAMES)
