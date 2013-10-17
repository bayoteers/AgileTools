# -*- Mode: perl; indent-tabs-mode: nil -*-

%::safe = (

'agiletools/process/1_summary_links.html.tmpl' => [
  'columnlist',
  'team.id',
  'team.current_sprint.id',
  'bl.id',
],

'hook/list/edit-multiple-after_custom_fields.html.tmpl' => [
  'pool.id',
],

'hook/bug/edit-after_custom_fields.html.tmpl' => [
  'pool.id',
  'bug.pool_id',
  'bug.pool_order',
],

'pages/agiletools/scrum/planning.html.tmpl' => [
  'team.id',
  'sprint_id',
  'backlog_id',
  'bl.id',
],

'pages/agiletools/scrum/sprints.html.tmpl' => [
  'columnlist',
  'team.id',
  'sprint.id',
  'sprint.capacity',
  'sprint.items_on_commit',
  'sprint.items_on_close',
  'sprint.estimate_on_commit',
  'sprint.estimate_on_close',
  'sprint.resolved_on_close',
  'sprint.effort',
  'sprint.items_completion FILTER format(\'%d %%\')',
  'sprint.effort_completion FILTER format(\'%d %%\')',

],

'pages/agiletools/team/create.html.tmpl' => [
  'p.key',
],

'pages/agiletools/team/list.html.tmpl' => [
  'team.id',
],

'pages/agiletools/team/show.html.tmpl' => [
  'team_json',
  'role.id',
  'bl.id',
],

'pages/agiletools/user_summary.html.tmpl' => [
  'team.id',
],

);
