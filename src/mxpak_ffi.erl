-module(mxpak_ffi).
-include_lib("kernel/include/file.hrl").
-export([get_arguments/0, ensure_apps_started/0, get_home_dir/0, make_hard_link/2, file_info/1, list_dir_recursive/2]).
get_arguments() ->
    Raw = init:get_plain_arguments(),
    Cleaned = strip_script_name(Raw),
    [to_binary(A) || A <- Cleaned].
strip_script_name([]) -> [];
strip_script_name([First | Rest] = All) ->
    try escript:script_name() of
        ScriptName ->
            FirstStr = case First of
                B when is_binary(B) -> binary_to_list(B);
                L when is_list(L) -> L
            end,
            case FirstStr =:= ScriptName of
                true -> Rest;
                false -> All
            end
    catch
        _:_ -> All
    end.
to_binary(A) when is_binary(A) -> A;
to_binary(A) when is_list(A) ->
    case unicode:characters_to_binary(A) of
        Bin when is_binary(Bin) -> Bin;
        _ -> <<>>
    end;
to_binary(_) -> <<>>.
ensure_apps_started() ->
    ensure_apps_started([gun, inets, ssl]).
ensure_apps_started([]) ->
    {ok, nil};
ensure_apps_started([Application | Rest]) ->
    case application:ensure_all_started(Application) of
        {ok, _} ->
            ensure_apps_started(Rest);
        {error, Reason} ->
            Name = atom_to_binary(Application),
            {error, {runtime_application_could_not_start, Name, format_reason(Reason)}}
    end.
get_home_dir() ->
    case os:getenv("HOME") of
        false ->
            case os:getenv("USERPROFILE") of
                false -> {error, missing_value};
                Path -> {ok, unicode:characters_to_binary(Path)}
            end;
        Path -> {ok, unicode:characters_to_binary(Path)}
    end.
make_hard_link(Existing, New) ->
    case file:make_link(binary_to_list(Existing), binary_to_list(New)) of
        ok -> {ok, nil};
        {error, Reason} ->
            Message = format_reason(Reason),
            {error, {hard_link_could_not_be_created, Existing, New, Message}}
    end.
file_info(Path) ->
    case file:read_file_info(binary_to_list(Path)) of
        {ok, Info} ->
            Size = Info#file_info.size,
            Inode = Info#file_info.inode,
            {ok, {Size, Inode}};
        {error, Reason} ->
            Message = format_reason(Reason),
            {error, {file_metadata_could_not_be_read, Path, Message}}
    end.
list_dir_recursive(Dir, ExcludeDirs) ->
    case file:list_dir(binary_to_list(Dir)) of
        {ok, Entries} ->
            list_entries_recursive(Entries, Dir, ExcludeDirs, []);
        {error, Reason} ->
            Message = format_reason(Reason),
            {error, {directory_could_not_be_listed, Dir, Message}}
    end.
list_entries_recursive([], _Dir, _ExcludeDirs, Acc) ->
    {ok, lists:reverse(Acc)};
list_entries_recursive([EntryL | Rest], Dir, ExcludeDirs, Acc) ->
    Entry = unicode:characters_to_binary(EntryL),
    Full = <<Dir/binary, <<"/">>/binary, Entry/binary>>,
    case lists:member(Entry, ExcludeDirs) of
        true ->
            list_entries_recursive(Rest, Dir, ExcludeDirs, Acc);
        false ->
            case filelib:is_dir(binary_to_list(Full)) of
                true ->
                    case list_dir_recursive(Full, ExcludeDirs) of
                        {ok, Sub} ->
                            list_entries_recursive(Rest, Dir, ExcludeDirs, lists:reverse(Sub, Acc));
                        {error, _} = Error ->
                            Error
                    end;
                false ->
                    list_entries_recursive(Rest, Dir, ExcludeDirs, [Full | Acc])
            end
    end.
format_reason(Reason) ->
    unicode:characters_to_binary(io_lib:format("~p", [Reason])).
