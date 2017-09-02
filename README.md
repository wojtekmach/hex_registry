hex_registry
============

**Warning: Work in progress**

An implementation of Hex Registry v2 specification [1].

[1] <https://github.com/hexpm/specifications/blob/master/registry-v2.md>

Example
-------

Let's grab the names of all packages in the Hex.pm registry:

```erlang
Url = "https://repo.hex.pm/names",
{ok, {{_, 200, _}, _Headers, Body}} = httpc:request(get, {Url, []}, [], [{body_format, binary}]).
Packages = hex_registry:decode_names(Body).
```

Output:

```erlang
#{packages =>
      [#{name => <<"a_message">>},
       #{name => <<"aatree">>},
       ...
      ]}
```

```erlang
length(maps:get(packages, Packages)).
# => 4789 (as of 2017-09-03)
```
