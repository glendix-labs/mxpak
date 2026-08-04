-module(mxpak_zip_ffi).
-export([unzip_to_memory/1]).
%% Returns the runtime representation of ArchiveCouldNotBeExtracted on failure.
unzip_to_memory(ZipBinary) ->
    case zip:unzip(ZipBinary, [memory]) of
        {ok, Entries} ->
            BinEntries = [{unicode:characters_to_binary(F), C} || {F, C} <- Entries],
            {ok, BinEntries};
        {error, Reason} ->
            Message = unicode:characters_to_binary(io_lib:format("~p", [Reason])),
            {error, {archive_could_not_be_extracted, Message}}
    end.
