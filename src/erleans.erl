%%%--------------------------------------------------------------------
%%% Copyright Space-Time Insight 2017. All Rights Reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%-----------------------------------------------------------------

%%% ---------------------------------------------------------------------------
%%% @doc
%%% @end
%%% ---------------------------------------------------------------------------
-module(erleans).

-export([get_grain/2,
         get_stream/2,
         get_stream/3]).

-include("erleans.hrl").

-type provider() :: {module(), atom()}.

-type grain_ref() :: #{implementing_module := module(),
                       id                  := term(),
                       placement           := placement(),
                       provider            => provider() | undefined}.

-type stream_ref() :: #{topic           := term(),
                        stream_module   := module(),
                        stream_provider := atom(),
                        fetch_interval  := integer()}.

-type placement() :: random | prefer_local | stateless | {stateless, integer()} | system_grain. %% | load

-type etag() :: integer().

-export_type([grain_ref/0,
              stream_ref/0,
              placement/0,
              provider/0,
              etag/0]).

-spec get_grain(module(), any()) -> grain_ref().
get_grain(ImplementingModule, Id) ->
    Placement = placement(ImplementingModule),
    BaseGrainRef = #{implementing_module => ImplementingModule,
                     placement => Placement,
                     id => Id},
    case Placement of
        {stateless, _} ->
            BaseGrainRef#{provider => undefined};
        _ ->
            BaseGrainRef#{provider => provider(ImplementingModule)}
    end.

-spec get_stream(module(), term()) -> stream_ref().
get_stream(StreamProvider, Topic) ->
    get_stream(StreamProvider, Topic, ?INITIAL_FETCH_INTERVAL).

-spec get_stream(module(), term(), pos_integer()) -> stream_ref().
get_stream(StreamProvider, Topic, FetchInterval) ->
    StreamConfig = proplists:get_value(StreamProvider, erleans_config:get(stream_providers, [])),
    StreamModule = proplists:get_value(module, StreamConfig),
    #{topic => Topic,
      stream_module => StreamModule,
      stream_provider => StreamProvider,
      fetch_interval => FetchInterval}.

-spec provider(module()) -> provider().
provider(CbModule) ->
    case erleans_utils:fun_or_default(CbModule, provider, undefined) of
        undefined ->
            undefined;
        Name ->
            find_provider_config(Name)
    end.

-spec find_provider_config(atom()) -> provider().
find_provider_config(default) ->
    %% throw an exception if default_provider is set to default, which would cause an infinite loop
    case erleans_config:get(default_provider) of
        default ->
            throw(bad_default_provider_config);
        _ ->
            find_provider_config(erleans_config:get(default_provider))
    end;
find_provider_config(Name) ->
    case proplists:get_value(Name, erleans_config:get(providers, [])) of
        undefined ->
            throw({missing_provider_config, Name});
        ProviderOptions ->
            Module = proplists:get_value(module, ProviderOptions),
            {Module, Name}
    end.

-spec placement(module()) -> placement().
placement(Module) ->
    case erleans_utils:fun_or_default(Module, placement, ?DEFAULT_PLACEMENT) of
        stateless ->
            {stateless, erleans_config:get(default_stateless_max, 5)};
        Placement ->
            Placement
    end.
