# Rebar Plugin -> GitConf
---
This plugin could automatic download configure files from your git server, it will be helps you to management the configure files by git, and you can trace the every version of your configure files.

If you are using git-flow, you'd better use the same branch name between code project and configure project, for example

your code project url :

```
git@github.com:erlang-china/my_project.git
```

and your configure project url:

```
git@mycompany.com:production-configs/my_project.git
```

and between these two git repos, also have two infinity branches:master and develop, and have support branches:features, hotfix and release, while you develop on different branch, you'd better get the same branch configure branches.

e.g.

if you are develop on hotfix branches, you'd better also checkout hotfix configure branch, and if you modified the configure files, you also need follow the git-flow steps to merge your configure branchs.


#### use as rebar plugin

1.Configure your rebar.config according to the following .

```erlang
{plugins, [rebar_gitconf]}.
{configs, [{git, "git@github.com:config_center/rebar_plugin_gitconf.git"}, 
             {branch, "master"},
             {dst, "etc"},
             {template, ["*.config"]},
             {place_hold_script, "scripts/place_hold_script.erl"}
             ]}.
%% the section git,dst is require,
%% and branch, template, place_hold_script are optional
%% if there did not have the key of branch, 
%% this plugin will get your code project's branch name
%% you could customize your place holder's, this plugin will load your script to replace it
%% place holder script e.g : ["{#HOST_NAME#}", fun()-> net_adm:localhost() end]
%%                           this plugin will auto replace the '{#HOST_NAME#}' into your real host name
```

2.The plugin can be installed globally into the user’s erl environment (for example by putting it’s application root directory somewhere on the ERL_LIBS environment variable), or by fetching it into the project’s dependencies.

#### package in rebar

*steps*

1.  put the rebar_gitconf.erl into rebar's src dir.
2.  modify the rebar.erl, put some command descriptions (optional).
3.  modify ebin/rebar.app, add `rebar_gitconf` to section of `modules` and `app_dir`.
4.  rebuild your rebar and enjoy it.


#### command

```
$ ./rebar get-configs
$ ./rebar delete-configs
```
