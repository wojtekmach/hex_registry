-module(hex_registry).
-include_lib("eunit/include/eunit.hrl").

%% API exports
-export([encode/4, decode/3, encode_names/3, decode_names/1, encode_versions/3, decode_versions/1, encode_package/3, decode_package/1]).

%%====================================================================
%% API functions
%%====================================================================

encode_names(Repository, Signature, Packages) ->
    Packages2 = [#{name => Name, repository => Repository} || #{name := Name} <- Packages],
    encode(#{packages => Packages2}, hex_pb_names, 'Names', Signature).

decode_names(Body) ->
    decode(Body, hex_pb_names, 'Names').

encode_versions(Repository, Signature, Packages) ->
    Packages2 = lists:map(fun(Package) -> encode_version(Repository, Package) end, Packages),
    hex_registry:encode(#{packages => Packages2}, hex_pb_versions, 'Versions', Signature).

decode_versions(Body) ->
    decode(Body, hex_pb_versions, 'Versions').

%% FIXME: _Repository
encode_package(_Repository, Signature, #{releases := Releases}) ->
    Releases2 = lists:map(fun(Release) ->
                 Release2 = remove_empty_retired(Release),
                 Release3 = maps:update_with(checksum, fun decode16/1, Release2),
                 Release3
               end, Releases),
    encode(#{releases => Releases2}, hex_pb_package, 'Package', Signature).

decode_package(Body) ->
    decode(Body, hex_pb_packages, 'Package').

encode(Payload, Module, Message, Signature) ->
    Payload2 = apply(Module, encode_msg, [Payload, Message]),
    Signed = sign_protobuf(Payload2, Signature),
    zlib:gzip(Signed).

%% TODO: Check signature when decoding
decode(Body, Module, Message) ->
    Uncompressed = zlib:gunzip(Body),
    #{payload := Payload, signature := _Signature} =
        hex_pb_signed:decode_msg(Uncompressed, 'Signed'),
    apply(Module, decode_msg, [Payload, Message]).

%%====================================================================
%% Internal functions
%%====================================================================

encode_version(Repository, #{releases := Releases} = Package) ->
    Versions = [Version || #{version := Version} <- Releases],
    Retired = [Index || {#{retired := #{}}, Index} <- with_index(Releases)],
    Package#{repository => Repository, versions => Versions, retired => Retired}.

sign_protobuf(Payload, Signature) ->
    hex_pb_signed:encode_msg(#{payload => Payload, signature => Signature}, 'Signed').

remove_empty_retired(#{retired := nil} = Release) ->
    maps:without([retired], Release);
remove_empty_retired(Release) ->
    Release.

with_index(List) ->
  lists:zip(List, lists:seq(0, length(List) - 1)).

%% https://github.com/goj/base16/blob/1.0.0/src/base16.erl#L21
decode16(Base16) when size(Base16) rem 2 =:= 0 ->
    << <<(unhex(H) bsl 4 + unhex(L))>> || <<H,L>> <= Base16 >>.

unhex(D) when $0 =< D andalso D =< $9 ->
    D - $0;
unhex(D) when $a =< D andalso D =< $f ->
    10 + D - $a;
unhex(D) when $A =< D andalso D =< $F ->
    10 + D - $A.
