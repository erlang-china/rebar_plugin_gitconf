-module(rebar_gitconf).

-export(['get-configs'/2,
         'delete-configs'/2]).

-include("rebar.hrl").

-define(CMD_GITURL,       "git config --get remote.origin.url").
-define(CMD_GITBRANCH(V), "git rev-parse --abbrev-ref " ++ (V)).
-define(CMD_GITUSER,      "git config --global user.name").
-define(REPLACE_LIST,[{"{#HOST_NAME#}", fun()-> H = net_adm:localhost(),H end},
                      {"{#IP#}",        fun()-> H = net_adm:localhost(), {ok,[H2|_T]} = inet:getaddrs(H,inet), inet_parse:ntoa(H2) end}]).

'get-configs'(Config, File)->
    Dir = rebar_utils:get_cwd(),
    {_Config1, AppName} = rebar_app_utils:app_name(Config, File),

    case if_need_config(Config, Dir) of 
        {true, GitUrl, Branch, Dst, Templates, ExtPHDef} ->
                io:format("---~n    ~p configs~n    configs git\t\t: ~p~n    configs branch\t: ~p~n    destination dir\t: ~p~n---~n",[AppName, GitUrl, Branch, Dst]),
                case download_configs(Dst, {git, GitUrl, Branch}) of
                    ok ->
                        regen_configs(Templates, Dst, ExtPHDef);
                    _->
                        ok
                end,
                ok;
        false->
                ok
    end.

'delete-configs'(Config, _File)->
    Dir                 = rebar_utils:get_cwd(),
    case if_need_config(Config, Dir) of 
        {true, _GitUrl, _Branch, Dst, _Template, _ExtPHDef} ->
            delete_configs(Dst);
        false->
            ok
    end,
    ok.

if_need_config(Config, Dir) ->
    LocalConfig = rebar_config:get_local(Config, configs, undefined),
    case LocalConfig of
        undefined ->
            false;
        V ->
            case proplists:get_value(git, V) of
                undefined->
                    false;
                GitUrl->
                    Dst = proplists:get_value(dst, V),
                    case Dst of 
                        undefined->
                            false;
                        _->
                            Branch = 
                            case proplists:get_value(branch, V) of 
                                undefined->
                                    {_Config3, Rev0}  = rebar_utils:vcs_vsn(Config, {cmd, ?CMD_GITBRANCH("HEAD")}, Dir),
                                    Rev0;
                                Branch0 ->
                                    Branch0
                            end,
                            Template     = proplists:get_value(template, V, []),
                            ExtPHDefFile = proplists:get_value(place_hold_script, V),
                            {ok, FBin}   = file:read_file(ExtPHDefFile),
                            FStr = binary_to_list(FBin),
                            
                            ExtPHDef     =
                            case eval(FStr,[]) of 
                                PHList when is_list(PHList)->
                                    PHList;
                                OtherResult->
                                    ?DEBUG("error place holder script: ~s\n", [OtherResult]),
                                    []
                            end,
                            {true, GitUrl, Branch, Dst, Template, ExtPHDef}
                    end
            end
    end.

download_configs(AppDir, {git, Url, Rev}) ->
    case filelib:is_dir(AppDir) of
        false ->
            ok = filelib:ensure_dir(AppDir),
            rebar_utils:sh(?FMT("git clone -n ~s ~s", [Url, filename:basename(AppDir)]),[]),
            rebar_utils:sh(?FMT("git checkout -q ~s", [Rev]), [{cd, AppDir}]),
            ok;
        true->
            ignore
    end.

delete_configs(Dir) ->
    case filelib:is_dir(Dir) of
        true ->
            ?INFO("Deleting configure files: ~s\n", [Dir]),
            rebar_file_utils:rm_rf(Dir);
        false ->
            ok
    end.

regen_configs(Templates, Dir, ExtPHDef) ->
    NewTemplates = [ filename:join([Dir,Template])|| Template <-Templates],
    Files = regen_configs0(NewTemplates, Dir, []),
    [
        begin 
            {ok, FileBin} = file:read_file(File),
            FileStr = binary_to_list(FileBin),
            FunReplace = fun({Old, NewStrFun},OutFileStr)->
                                gsub(OutFileStr, Old, NewStrFun())
                         end,

            NewFile = lists:foldl(FunReplace, FileStr, ?REPLACE_LIST ++ ExtPHDef),
            
            file:write_file(File, list_to_binary(NewFile)),
            File
        end
    ||File <-Files].
    

regen_configs0([], _Dir, AccOut) -> AccOut;
regen_configs0([Template|T], Dir, AccOut) ->
    Files = filelib:wildcard(Template),
    regen_configs0(T, Dir, AccOut ++ Files).



sub(Str,Old,New) ->   
    Lstr = string:len(Str),   
    Lold = string:len(Old),   
    Pos  = string:str(Str,Old),   
    if  Pos =:= 0 ->Str;      
        true->           
            LeftPart = string:left(Str,Pos-1),           
            RitePart = string:right(Str,Lstr-Lold-Pos+1),           
            lists:flatten([lists:flatten([LeftPart,New]),RitePart])
    end.

gsub(Str,Old,New) ->  
    Acc = sub(Str,Old,New),  
    subst(Acc,Old,New,Str).

subst(Str,_Old,_New, Str) -> Str;
subst(Acc, Old, New,_Str) -> 
    Acc1 = sub(Acc,Old,New),         
    subst(Acc1,Old,New,Acc).

eval(Exprs,Environ) ->
    {ok,Scanned,_} = erl_scan:string(Exprs),
    {ok,Parsed} = erl_parse:parse_exprs(Scanned),
    {value,V,_B}=erl_eval:exprs(Parsed,Environ),
    V.