AgileTools Bugzilla Extension
=============================

This extension provides tools to manage teams and their processes.
Currently it supports Scrum process and provides planning and progress tracking
tools for teams using the Scrum process. In the future other process models,
for example Kanban, could be added.


Installation
============

This extension requires [BayotBase](https://github.com/bayoteers/BayotBase)
extension, so install it first.

1.  Put extension files in

        extensions/AgileTools

2.  Run checksetup.pl
 - If you have used the BAYOT Scrums extension earlier, setup will ask if you
   want to migrate the old Scrums teams to AgileTools.

3.  Restart your web server if needed (for example when running under mod_perl)

4.  Adjust the configuration values available in Administration > Parameters >
    AgileTools
