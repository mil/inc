#!/usr/bin/env ruby
require 'yaml'
require 'pp'
require 'shellwords'
require 'fileutils'

# Colorizing strings
class String
  def color(c)
    colors = { 
      :black   => 30, 
      :red     => 31, 
      :green   => 32, 
      :yellow  => 33, 
      :blue    => 34, 
      :magenta => 35, 
      :cyan    => 36, 
      :white   => 37 
    }
    "\e[#{colors[c] || c}m#{self}\e[0m"
  end
  def dir_parts
    self.split(File::SEPARATOR)
  end
end

#$incscript_preferences = {
#  :recursive_page_prefs   => true,
#  :recursive_post_prefs   => true,
#
#  :passthrough_extensions => ["jpg"],
#  :passthrough_paths      => [ ".htaccess" ]
#}

module Utilities
  def log(msg_type, msg)
    color = {
      :error => :red
    }[msg_type]

    puts "#{'ERROR:'.color(:magenta)}\n#{msg.color(color)}"
  end

  def assert(condition, error_msg)
    if !condition
      log :error, error_msg
      exit
    end
  end

  # Not cross platform -- will need to revisit
  def executable_exists?(executable_handle)
    %x[which #{executable_handle} 2>/dev/null][0] == "/"
  end

  def arrayify(string_or_array)
    string_or_array.class == Array ? 
      string_or_array : 
      [ string_or_array ]
  end

  def is_valid_incscript_folder?(folder)
    return (

      (File.exists? "#{folder}/incscript_config.yaml") &&
      (File.directory? "#{folder}/scripts") &&
      (File.directory? "#{folder}/filesystem") 
    )
  end
end



class Incscript
  include Utilities

  def initialize(source_folder, destination_folder)
    @incscript_root   = source_folder 
    @incscript_config = YAML.load_file "#{@incscript_root}/incscript_config.yaml"
    @filesystem       = "#{@incscript_root}/filesystem"
    @scripts          = "#{@incscript_root}/scripts"


    assert(
      (is_valid_incscript_folder? @incscript_root),
      [
        "Source folder is not a compatible incscript directory",
        "Ensure the following files and folders exist:",
        "   #{@incscript_root}/filesystem/",
        "   #{@incscript_root}/scripts/",
        "   #{@incscript_root}/incscript_config.yaml",
      ].join("\n")
    )

    # Root folder
    compile_folder( "", {}, destination_folder)
  end

  #fp_contents =  File.open(f) { |f| f.read }


  def extract_file_obj(fp)
    # Reads given file and returns an object 
    # with :frontend_matter and :content symbols
    # If file has no FEM, symbol will be nil
    # : {
    #   :frontend_matter => {},
    #   :content => "content after FEM"
    # }
    #
     return_obj = {
      :frontend_matter => {},
      :content         => ""
    }

    # limitation: does not deal with markdown '---' nested within page content
    fem_string = ""; within_fem = false  

    # Just dealining with content inline
    if !File.exists?("#{@filesystem}/#{fp}")
      return_obj[:content] = fp
    else 
      File.open("#{@filesystem}/#{fp}", 'r').read.each_line do |line|
        if line.chomp == "---" 
          within_fem = !within_fem
          next
        end

        (within_fem ? fem_string : return_obj[:content]) << line
      end
      return_obj[:frontend_matter] = YAML.load fem_string

    end


    # Has a contents property can reference
    # to other file(s)
    if (
      return_obj[:frontend_matter] &&
      return_obj[:frontend_matter]['page'] && 
      return_obj[:frontend_matter]['page']['contents']
    ) then
      return_obj[:content] = ""
      arrayify(return_obj[:frontend_matter]['page']['contents']).each do |p|
        return_obj[:content] << compile_file(p, {})
      end
    end

    return return_obj
  end

  def pipe_text_through_scripts(text_string, scripts_array)
    buffer = text_string

    scripts_array.each do |script|
      if Dir.glob("#{@scripts}/*").map { |s|
        s.dir_parts.last
      }.include?(script) then
        buffer = %x[echo #{Shellwords.escape buffer.chomp} | ./#{@scripts}/#{script} ]
      elsif executable_exists?(script) then
        buffer = `echo #{Shellwords.escape buffer} | #{script}`
      end


    end 
    buffer
  end

  def compile_file(file_path, prefs)
    parsed = extract_file_obj(file_path)


    prefs.merge!(
      (parsed[:frontend_matter] || {})
    )

    # Just straight up text include
    return parsed[:content] if prefs == {}

    post_content = pipe_text_through_scripts(
      parsed[:content], arrayify(prefs['page']['scripts'])
    )

    before = ""; after  = ""
    if prefs['once_page_is_compiled'] then
      [
        [prefs['once_page_is_compiled']['prepends']  || [], before],
        [prefs['once_page_is_compiled']['postpends'] || [], after]
      ].each do |p|
        arrayify(p[0]).each do |f| 
          p[1] <<  compile_file(f, {})
        end
      end

      if prefs['once_page_is_compiled']['scripts'] then
        post_content = pipe_text_through_scripts(
          post_content, arrayify(prefs['once_page_is_compiled']['scripts'])
        )
      end

    end


 
    "#{before}\n#{post_content}\n#{after}"
  end





  def compile_folder(source_folder, imported_prefs = {}, destination_folder = nil)
    folder_prefs = (File.exists? "#{@filesystem}/#{source_folder}/_incscript.yaml") ?  
      (YAML.load_file "#{@filesystem}/#{source_folder}/_incscript.yaml") : {}
    prefs        = imported_prefs.merge! folder_prefs

    FileUtils.rm_rf destination_folder
    Dir.mkdir destination_folder


    # Loop children files and folders 
    Dir.glob("#{@filesystem}#{source_folder}/*").select do |f|
      next if File.split(f).last[0] == '_'
      f = f.split(@filesystem).last

      if (File.directory? "#{@filesystem}/#{f}") then
        compile_folder(f, prefs, "#{destination_folder}/#{f.dir_parts.last}")
      else
        target_directory = destination_folder
        target_file = f.dir_parts.last

        puts "#{'Compiling'.color(:red)} #{target_file.color(:blue)}"

        if @incscript_config['create_wrapper_folder']['extensions'].include? File.extname(f)[1..-1]
          created_folder   = File.basename(f, File.extname(f))
          target_directory = "#{destination_folder}/#{created_folder}"
          target_file      = "index.html"

          Dir.mkdir target_directory
        end


        # Compile file, write to destination
        compiled_file = compile_file(f, prefs)
        File.open("#{target_directory}/#{target_file}", 'w') do |f|
          f.write compiled_file
        end

      end
    end
  end

end

Incscript.new( ARGV.first, ARGV.last )
