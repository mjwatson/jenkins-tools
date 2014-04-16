require 'thor'
require 'yaml'
require 'mustache'
require 'fileutils'

class MustacheFormatter
  def render(template, options)
    Mustache.render(template.to_sym, options) 
  end
end

class TemplateTools

    def initialize(e, o)
      @options = o
      @entries = e
    end

    def list
      entries_to_write.each { |component, name, data|
        puts "#{component}/#{name}"
      }
    end

    def write
       entries_to_write.each { |component, name, data|
         output(component, name, data)
       }
    end
   
    private

    def options
      @options
    end

    def entries
      @entries
    end

    def folder
      options[:folder]
    end

    def template_root
      options[:template] || File.dirname(config_path)
    end

    def config_path
      options[:config]
    end

    def regex
      options[:regex] || ""
    end

    def entries_to_write
      entries
      .find_all { |c,n,t,o| "#{c}/#{n}" =~ Regexp.new(regex) }
      .map { |c,n,t,o| [c, n, compile(t, o)] }
    end

    def template_instance
      options.fetch(:formatter, MustacheFormatter).new
    end

    def compile(template, template_options)
      template_path = "#{template_root}/#{template}"
      template_instance.render(template_path, template_options) 
    end

    def output(*args)
      if folder
        folder_output(*args)
      else
        std_output(*args)
      end
    end

    def folder_output(component, name, data)
      path = "#{folder}/#{component}/#{name}"
      dirname = File.dirname(path)
      FileUtils.mkdir_p(dirname)
      File.open(path, "w") { |f|
        f.write data
      }
    end

    def std_output(component, name, data)
      puts data
    end
end

class TemplateToolsCLI < Thor

  class_option :config,  :aliases => "-c", :desc => "The configuration file", :default => "config.yml"
  class_option :template,:aliases => "-t", :desc => "The root path for templates."
  class_option :regex,   :aliases => "-r", :desc => "Restrict to files matching regex"
  class_option :folder,  :aliases => "-f", :desc => "Folder to write to, otherwise writes to stdout."

  desc "list", "Lists the generated files."
  def list
    tt.list
  end

  desc "write", "Writes the files to standard out or a folder"
  def write
    tt.write
  end

  private

  def tt
    TemplateTools.new(get_entries, options)
  end

  def config_path
    options[:config]
  end

  def read_config(path)
    YAML.load_file(path)
  end

  def get_entries
    config  = read_config(config_path)
    groups  = build_groups(config)
    entries = build_entries(config, groups)
    entries
  end

  def build_groups(config)
    config["groups"]
  end

  def build_entries(config, groups)
    entries = []
    entry_config = config["entries"]
    if entry_config
      entry_config.each { |component, elements|
        elements.each { |name, options|
          case
          when options["template"]
            entries << [component, name, options["template"], options]
          when options["group"]
            compile_group(groups, options["group"], name, options).each { |outname, template|
              entries << [component, outname, template, options]
            }
          else
            raise "Entry #{component} #{name} must be either template or group."
          end
        }
      }
    end
    entries
  end

  def compile_group(groups, group_name, name, options)
    unless groups and groups[group_name]
      raise "Invalid group name: #{group_name}"
    end

    begin
      groups[group_name].map { |instance_name, instance_options|
        name = Mustache.render(instance_options["name"], options)
        [name, instance_options["template"]]
      }
    rescue 
      raise "Invalid group compilation: #{group_name} <- #{name}"
    end
  end
end

if $0 == __FILE__
  TemplateToolsCLI.start(ARGV)
end
