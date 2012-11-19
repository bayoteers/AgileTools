AgileTools Bugzilla Extension
=============================

This extension provides tools to manage teams and their processes.
Currently it supports Scrum process and provides planning and progress tracking
tools for teams using the Scrum process. In the future other process models,
for exmaple Kanban, could be added.


Installation
============

This extension requires [BayotBase](https://github.com/bayoteers/BayotBase)
extension, so install it first.

1.  Put extension files in

        extensions/AgileTools

2.  Run checksetup.pl

3.  Restart your webserver if needed (for exmple when running under mod_perl)

4.  Adjust the configuration values available in Administration > Parameters >
    AgileTools


If you have used the BAYOT Scrums extension earlier, you can migrate the old
existing teams to AgileTools by running the migration script included inthe 
extension directory.

    ./extensions/AgileTools/migrate_bayot_scrums.pl

This will copy the old teams, backlogs and sprints over to AgileTools

