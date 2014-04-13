jenkins-tools
=============

Simple ruby tools to help manage a jenkins CI installation.

All very much work in progress...

Currently provides two scripts:

* jenkins-tools.rb provides a command line interface for managing jenkins jobs, views and nodes.
  For each, it can:
  - list the current entries
  - pull down the config.xml
  - push a new config.xml for an existing or new entry
  - delete an entry

  It supports pulling down all config.xml and storing them in a folder on a file system.
  For example job-one, would be stored in $folder/job/job-one.xml.

  The script can then push from a similar folder structure, updating and adding jobs as necessary.


* template-tools.rb provides a command line interface for generating such a folder structure.

  It currently accepts a yaml configuration file and mustache templates.
  The configuration file specifies the output files that should be generated from which templates and which options.
  It also allows groups of templates to be specified, which can then be generated from the same set of configuration options.

