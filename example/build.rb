require '../template-tools.rb'

class TemplateBuilder

  BRANCHES = [ "FOO", "BAR" ]

  JOBS = [ "A", "B", "C" ]

  OPTIONS = {
    :folder => "OUT"
  }

  def add(a)
    entries << a
  end

  def entries
    @entries ||= []
  end

  def run
    BRANCHES.each { |branch|
      JOBS.each { |job|
        build(branch, job)
      }
    }

    TemplateTools.new(entries, OPTIONS).write
  end

  def build(branch, job)
    add [ branch, job, "template", { :say => job.upcase, :what => branch.downcase } ]
  end
end

if $0 == __FILE__
  TemplateBuilder.new.run
end
