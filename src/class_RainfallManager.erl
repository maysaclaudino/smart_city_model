%Class that manage the parking spots in the city
-module(class_RainfallManager).

% Determines what are the mother classes of this class (if any):
-define( wooper_superclasses, [ class_Actor ] ).

% parameters taken by the constructor ('construct').
-define( wooper_construct_parameters, ActorSettings , RainfallName , ListRainfall ).

% Declaring all variations of WOOPER-defined standard life-cycle operations:
% (template pasted, just two replacements performed to update arities)
-define( wooper_construct_export, new/3, new_link/3,
		 synchronous_new/3, synchronous_new_link/3,
		 synchronous_timed_new/3, synchronous_timed_new_link/3,
		 remote_new/4, remote_new_link/4, remote_synchronous_new/4,
		 remote_synchronous_new_link/4, remote_synchronisable_new_link/4,
		 remote_synchronous_timed_new/4, remote_synchronous_timed_new_link/4,
		 construct/4, destruct/1 ).

% Method declarations.
-define( wooper_method_export, actSpontaneous/1, onFirstDiasca/2 ).


% Allows to define WOOPER base variables and methods for that class:
-include("smart_city_test_types.hrl").

% Allows to define WOOPER base variables and methods for that class:
-include("wooper.hrl").

-spec construct( wooper:state(), class_Actor:actor_settings(),
				class_Actor:name() , parameter() ) -> wooper:state().
construct( State, ?wooper_construct_parameters ) ->
    
	Rainfall = dict:from_list( ListRainfall ),

	ActorState = class_Actor:construct( State, ActorSettings , RainfallName ),

	case ets:info(rainfall) of
		undefined -> ets:new(events, [public, set, named_table]);
		_ -> ok
	end,

	setAttributes( ActorState, [ { rainfall , Rainfall } ] ).

-spec destruct( wooper:state() ) -> wooper:state().
destruct( State ) ->

    State.

-spec actSpontaneous( wooper:state() ) -> oneway_return().
actSpontaneous( State ) ->

	Rainfall = getAttribute( State, rainfall ),
	CurrentTickOffset = class_Actor:get_current_tick_offset( State ), 

	NewState = case dict:find(  CurrentTickOffset, Rainfall ) of
			   {ok, CurrentRainfall} -> print_rainfall( State, CurrentRainfall );
			   error -> State
		   end,

	executeOneway( NewState , addSpontaneousTick, CurrentTickOffset + 1 ).

print_rainfall( State, CurrentRainfall ) ->
	io:format("Rainfall: ~p~n", [CurrentRainfall]),
	State.

-spec onFirstDiasca( wooper:state(), pid() ) -> oneway_return().
onFirstDiasca( State, _SendingActorPid ) ->

	CurrentTickOffset = class_Actor:get_current_tick_offset( State ), 
	executeOneway( State , addSpontaneousTick, CurrentTickOffset + 1 ).
