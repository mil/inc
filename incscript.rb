#!/usr/bin/env ruby
require 'yaml'
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

    compile_folder( @filesystem, {}, destination_folder)
  end

  #fp_contents =  File.open(f) { |f| f.read }



  def parse_file(file_path)
    # Reads given file and returns an object 
    # with :frontend_matter and :content symbols
    # If file has no FEM, symbol will be nil
    # : {
    #   :frontend_matter => {},
    #   :content => "content after FEM"
    # }
    

    return_obj = {
      :frontend_matter => nil,
      :content         => ""
    }

    # limitation: does not deal with markdown '---' nested within page content
    fem_string = ""; within_fem = false  
    File.open(file_path, 'r').read.each_line do |line|
      ((within_fem = !within_fem) && next) if line.chomp == "---" 
      puts "<#{line.chomp}>"

      (within_fem ? fem_string : return_obj[:content]) << line
    end
    return_obj[:frontend_matter] = YAML.load fem_string

    return_obj
  end


  def compile_folder(source_folder, imported_prefs = {}, destination_folder = nil)
    folder_prefs = (File.exists? "#{source_folder}/_incscript.yaml") ?  
      (YAML.load_file "#{source_folder}/_incscript.yaml") : {}
    prefs        = imported_prefs.merge! folder_prefs

    FileUtils.rm_rf destination_folder
    Dir.mkdir destination_folder


    # Loop children files and folders 
    Dir.glob("#{source_folder}/*").select do |f|
      next if File.split(f).last[0] == '_'

      if (File.directory? f) then
        compile_folder(f, prefs, "#{destination_folder}/#{f.dir_parts.last}")
      else
        target_directory = destination_folder
        target_file = f.dir_parts.last

        if @incscript_config['create_wrapper_folder']['extensions'].include? File.extname(f)[1..-1]
          created_folder   = File.basename(f, File.extname(f))
          target_directory = "#{destination_folder}/#{created_folder}"
          target_file      = "index.html"

          Dir.mkdir target_directory
        end

        parsed_file = parse_file f

        #file_prefs = YAML.load_file f
        #@insc_prefs.merge! folder_prefs.merge file_prefs
        File.open("#{target_directory}/#{target_file}", 'w') do |f|
          f.write parsed_file[:content]
        end

      end
    end
  end

end

Incscript.new( ARGV.first, ARGV.last )
