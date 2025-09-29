%Class that manage the parking spots in the city
-module(class_RainfallManager).

% Determines what are the mother classes of this class (if any):
-define( wooper_superclasses, [ class_Actor ] ).

% parameters taken by the constructor ('construct').
-define( wooper_construct_parameters, ActorSettings , RainfallName , ListRainfall, ListFlood ).

% Declaring all variations of WOOPER-defined standard life-cycle operations:
% (template pasted, just two replacements performed to update arities)
-define( wooper_construct_export, new/4, new_link/4,
		 synchronous_new/4, synchronous_new_link/4,
		 synchronous_timed_new/4, synchronous_timed_new_link/4,
		 remote_new/5, remote_new_link/5, remote_synchronous_new/5,
		 remote_synchronous_new_link/5, remote_synchronisable_new_link/5,
		 remote_synchronous_timed_new/5, remote_synchronous_timed_new_link/5,
		 construct/5, destruct/1 ).

% Method declarations.
-define( wooper_method_export, actSpontaneous/1, onFirstDiasca/2 ).


% Allows to define WOOPER base variables and methods for that class:
-include("smart_city_test_types.hrl").

% Allows to define WOOPER base variables and methods for that class:
-include("wooper.hrl").

-spec construct( wooper:state(), class_Actor:actor_settings(),
				class_Actor:name() , parameter(), parameter() ) -> wooper:state().
construct( State, ?wooper_construct_parameters ) ->
    
	Rainfall = dict:from_list( ListRainfall ),
	Flood = group_duplicates( ListFlood ),
	io:format("FLOOD MAP: ~p~n", [Flood]),

	ActorState = class_Actor:construct( State, ActorSettings , RainfallName ),

	case ets:info(rainfall) of
		undefined -> ets:new(events, [public, set, named_table]);
		_ -> ok
	end,

	setAttributes( ActorState, [ 
		{ rainfall , Rainfall },
		{ flood , Flood },
		{ accumulated_rainfall , 0.0 }
	] ).

-spec destruct( wooper:state() ) -> wooper:state().
destruct( State ) ->

    State.

-spec actSpontaneous( wooper:state() ) -> oneway_return().
actSpontaneous( State ) ->

	Rainfall = getAttribute( State, rainfall ),
	CurrentTickOffset = class_Actor:get_current_tick_offset( State ), 

	NewState = case dict:find(  CurrentTickOffset, Rainfall ) of
			   {ok, CurrentRainfall} -> process_rainfall( State, CurrentRainfall, CurrentTickOffset );
			   error -> State
		   end,

	executeOneway( NewState , addSpontaneousTick, CurrentTickOffset + 1 ).

-spec process_rainfall( wooper:state(), number(), integer() ) -> wooper:state().
process_rainfall( State, CurrentRainfall, CurrentTickOffset ) ->

	Rainfall = getAttribute( State, rainfall ),

	AccumulatedRainfall = calculate_accumulated_rainfall( Rainfall, CurrentTickOffset ),
	
	NewState = setAttribute( State, accumulated_rainfall, AccumulatedRainfall ),
	
	io:format("CurrentTickOffset: ~p | Rainfall: ~p | Accumulated: ~.2f~n", [CurrentTickOffset, CurrentRainfall, AccumulatedRainfall]),
	
	close_streets( NewState, AccumulatedRainfall ),

	NewState.

-spec calculate_accumulated_rainfall( dict:dict(), integer() ) -> number().
calculate_accumulated_rainfall( Rainfall, CurrentTime ) ->
	Period = 60 * 60 * 3, % 3 hours
	
	StartTime = CurrentTime - Period,
	
	AllKeys = dict:fetch_keys( Rainfall ),
	
	PeriodKeys = lists:filter( 
		fun( Time ) -> Time >= StartTime andalso Time =< CurrentTime end, 
		AllKeys 
	),
	
	% Return the sum of the rainfall values in the last period
	lists:sum( 
		lists:map( 
			fun( Time ) -> 
				case dict:find( Time, Rainfall ) of
					{ok, Value} -> Value;
					error -> 0
				end
			end, 
			PeriodKeys 
		) 
	).

-spec close_streets( wooper:state(), number() ) -> ok.
close_streets( State, AccumulatedRainfall ) ->
    Flood = getAttribute( State, flood ),
    CurrentTickOffset = class_Actor:get_current_tick_offset( State ),
    AllKeys = dict:fetch_keys( Flood ),

    RainfallKeys = lists:filter( 
        fun( RainfallLimit ) -> RainfallLimit =< AccumulatedRainfall end,
        AllKeys 
    ),

    io:format("RAINFALL ACHIEVED: ~p~n", [RainfallKeys]),
    
    lists:foreach(  % Use foreach em vez de map
        fun ( Rain ) ->
            case dict:find( Rain, Flood ) of
                {ok, StreetList} ->
                    io:format("TICK: ~p | SHOULD CLOSE STREETS: ~p~n", [CurrentTickOffset, StreetList]);
                error -> 
                    ok
            end
        end,
        RainfallKeys
    ),

    ok.

-spec group_duplicates( list() ) -> dict:dict().
group_duplicates(List) ->
    lists:foldl(fun({Key, Value}, Dict) ->
        case dict:find(Key, Dict) of
            {ok, ExistingValues} ->
                dict:store(Key, [Value | ExistingValues], Dict);
            error ->
                dict:store(Key, [Value], Dict)
        end
    end, dict:new(), List).

-spec onFirstDiasca( wooper:state(), pid() ) -> oneway_return().
onFirstDiasca( State, _SendingActorPid ) ->

	CurrentTickOffset = class_Actor:get_current_tick_offset( State ), 
	executeOneway( State , addSpontaneousTick, CurrentTickOffset + 1 ).
