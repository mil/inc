#!/usr/bin/env ruby
require 'yaml'

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
		return "\e[#{colors[c] || c}m#{self}\e[0m"
	end
end


$incscript_preferences = {
  # Config_path, Input, and Output
  # ==============================
  :input_directory        => "input",
  :output_directory       => "output",


  # Recursive Prefs
  # ===============
  # Enabling recursive preferences
  # makes it so that the 
  :recursive_page_prefs   => true,
  :recursive_post_prefs   => true,

  # Passthroughs
  # =============
  # Passthrough extensions and files
  # will be rendered as a 1-to-1 equivialnt
  # in the output folder as they appear in
  # the input folder.
  #
  # These files may be specified in two manners
  # 1st you may specify all files with a particular
  # extension (e.g. .jpg, .png, etc) will be passed through
  #
  # Alternativly, you may specify file or folder paths
  # in which individual files will be passed through.
  :passthrough_extensions => ["jpg"],
  :passthrough_paths      => [ ".htaccess" ]
}

def log(msg_type, msg)
  color = {
    :error => :red
  }[msg_type]

  puts msg.color(color)
end

def assert(condition, error_msg)
  if !condition
    log :error, error_msg
    exit
  end
end

def compile_file(file_path)
  puts "COMPILING"
  # Read file yaml
  #
  file_prefs = YAML.load_file file_path

  file_prefs['scripts'].each do |f|
    p "Reading file prefs" , f


  end

end


def compile(target_folder)
  assert(
    (File.exists? target_folder),
   "Target folder is compatible incscript directory" 
  )

  @insc_prefs = {}
  if File.exists? "_.incscript.yaml"
    folder_prefs = YAML.load_file "._incscript.yaml"
  end

  # Merge folder prefs into insc_prefs
  files = Dir.glob "*"

  Dir.glob("*").select do |f|
    if (File.directory? f) then
    else
    end
  end

  files.each do |f|
    file_prefs = YAML.load_file f

    [folder_prefs, file_prefs].each do |f|
      @insc_prefs.merge f
    end

    #compile_file f
  end


end

def proccess_args
  ARGV.each do |arg|
    if arg == "compile"
      compile "userbound.com_src"
    end
  end
end

proccess_args
