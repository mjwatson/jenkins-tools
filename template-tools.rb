require 'thor'
require 'yaml'
require 'mustache'
require 'fileutils'
  
class TemplateToolsCLI < Thor

    class_option :config,  :aliases => "-c", :desc => "The configuration file", :default => "config.yml"
    class_option :template,:aliases => "-t", :desc => "The root path for templates."
    class_option :regex,   :aliases => "-r", :desc => "Restrict to files matching regex"
    class_option :folder,  :aliases => "-f", :desc => "Folder to write to, otherwise writes to stdout."

    desc "list", "Lists the generated files."
    def list
      entries_to_write.each { |component, name, data|
        puts "#{component}/#{name}"
      }
    end

    desc "write", "Writes the files to standard out or a folder"
    def write
       writer = output
       entries_to_write.each { |component, name, data|
         writer.call(component, name, data)
       }
    end
    
    private

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
      get_entries.map { |component, name, template, options|
        [component, name, compile(template, options)]
      }
    end

    def get_entries
      config  = read_config(config_path)
      groups  = build_groups(config)
      entries = build_entries(config, groups)
      
      entries.find_all { |component, name, template, options|
        fullname = "#{component}/#{name}"
        fullname =~ Regexp.new(regex)
      }
    end

    def read_config(path)
       YAML.load_file(path)
    end

    def build_groups(config)
      config["groups"]
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

    def compile(template, options)
      template_path = "#{template_root}/#{template}"
      Mustache.render(template_path.to_sym, options) 
    end

    def output
      if folder
        Proc.new { |component, name, data|
            path = "#{folder}/#{component}/#{name}"
            dirname = File.dirname(path)
            FileUtils.mkdir_p(dirname)
            File.open(path, "w") { |f|
                f.write data
            }
        }
      else
        Proc.new { |component, name, data|
            puts data
        }
      end
    end
end

if $0 == __FILE__
  TemplateToolsCLI.start(ARGV)
end
