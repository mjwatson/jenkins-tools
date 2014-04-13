require 'jenkins_api_client'
require 'thor'
require 'fileutils'
  
class JenkinsToolsCLI < Thor

    class_option :username,    :aliases => "-u", :desc => "Name of Jenkins user"
    class_option :password,    :aliases => "-p", :desc => "Password of Jenkins user"
    class_option :server_ip,   :aliases => "-s", :desc => "Jenkins server IP address"
    class_option :server_port, :aliases => "-o", :desc => "Jenkins port"
    class_option :component,   :aliases => "-c", :desc => "Jenkins component type [all|job|view|node]", :default => "all"
    class_option :regex,       :aliases => "-r", :desc => "Restrict to jenkins components matching regex"
    class_option :folder,      :aliases => "-f", :desc => "Folder to sync to or from."

    desc "list", "Lists the jenkins jobs."
    def list
      jenkins_entries { |component, name|
        puts name
      }
    end

    desc "pull", "Pulls the jenkins configuration."
    def pull
        writer = pull_output
        jenkins_entries { |component, name|
          writer.call(component, name, client.send(component).get_config(name))
        }
    end

    desc "delete", "Deletes the jenkins configurations."
    def delete
      jenkins_entries { |component, name|
        client.send(component).delete(name)
      }
    end

    desc "push", "Pushes (ie installs/updates) the jenkins configuration."
    long_desc <<-LONGDESC
      This will push (install/update) a configuration to jenkins.

      To push a single file, the component and name must be specified (using the component and regex options respectively).
      The config xml should then be provided on stdin.
      eg
        cat job_config.xml | jenkins-tools.rb push -s 127.0.0.1 -c job -r job_name

      To push more then one configuration at once, specify a folder (using folder option) containing the configuration files 
      in the structure provided by pull (ie jobs in folder/job/job_name.xml etc).
      eg
        jenkins-tools.rb push -s 127.0.0.1 -f new_config

      Note: push cannot currently create nodes or reconfigure the master nodes.
    LONGDESC
    def push
       entries_to_push.each { |component, name, config_xml|
         push_entry(component, name, config_xml)
       }
    end
    
    private
    
    def client
      @client ||= connect
    end

    def connect
      JenkinsApi::Client.new(options)
    end

    def jenkins_entries
     components.each { |c|
       client.send(c).list(component_regex).each { |name|
         yield c, name
       }
     }
    end

    def components
      case options[:component]
      when "all"
        [:job, :view, :node]
      when "job"
        [:job]
      when "view"
        [:view]
      else
        raise "Bad component #{options[:component]}"
      end
    end

    def folder
      options[:folder]
    end

    def regex
      options[:regex]
    end

    def component_regex
      regex || ""
    end

    def pull_output
      if folder
        Proc.new { |component, name, data|
            path = "#{folder}/#{component}/#{name}.xml"
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

    def entries_to_push
      if folder
        folder_to_push
      else
        [single_entry_to_push]
      end
    end

    def listdir(path)
       Dir.foreach(path) { |e|
         unless ['.','..'].include? e
           yield e
         end
       }
    end

    def folder_to_push
      unless File.directory?(folder)
        raise "push requires folder to exist."
      end

      output = []

      listdir(folder) { |component|

        unless ['job','view','node'].include? component
          raise "push should reference folder only containing 'job', 'view' and 'node'"
        end

        dirpath = "#{folder}/#{component}"
        unless File.directory? dirpath
          raise "push should reference folder containing only folders."
        end

        component_sym = component.to_sym
        unless components.include? component_sym
          next
        end

        re = Regexp.new(component_regex)
        listdir(dirpath) { |filename|
          if re =~ filename
            File.open("#{dirpath}/#{filename}") { |f|
              output << [component.to_sym, filename.gsub('.xml',''), f.read]
            }
          end
        }
      }

      output
    end

    def single_entry_to_push
       if components.size != 1
         raise "push requires a folder or exactly one component type."
       end

       if not regex
         raise "push requires job name to be provided using --regex (-r) option."
       end

       [ components[0], regex, $stdin.read]
    end

    def push_entry(component, name, config_xml)
      case component
      when :job
        client.job.create_or_update(name, config_xml)
      when :view
        client.view.create(name) if client.view.list(name).empty?
        client.view.post_config(name, config_xml)
      when :node
        unless client.node.list(name).empty? or name == 'master'
          client.node.post_config(name, config_xml)
        end
      end
    end
end

if $0 == __FILE__
  JenkinsToolsCLI.start(ARGV)
end
