
class GameLobby extends View
    constructor: (@parent, @data_bus) ->
        @game_players =
            "local":
                "name": null,
                "color": null,
            "opponent":
                "name": null,
                "color": null,
        @opponent_name = null
        @local_name = null
        
        @local_joined = false
        @local_created = false
        @countdown_interval = 1000 # This var is to speed up tests
        
        @register_commands = ["lobby_players"]
        @register_variables =
            "game_players": => return @game_players, 
        @register_events =
            "game_lobby_done": [],
        
        @messages =
            null: null,
            
        super("game_lobby")
                
        lobby_box = $("\
        <div id='game_lobby_counter' class='lobster'>Finding a game...</div><br />
        <div id='game_lobby_box' class='border'>
            <div id='game_lobby_player_left'>
                <div id='game_lobby_player_left_text' class='impact'></div>
            </div>
            <div id='game_lobby_player_vs'>
                <div id='game_lobby_player_vs_text' class='lobster'></div>
            </div>
            <div id='game_lobby_player_right'>
                <div id='game_lobby_player_right_text' class='impact'></div>
            </div>
        </div>")
        
        @main_element
        .append(lobby_box)
        
        return
        
    # Handle initial game creation/joining
    receive_command: (command, value) ->
        if command == "lobby_players"
            opponent = value["opponent"]
        
            if opponent.length == 0
                @opponent_name = "???"
                @local_created = true
            else
                opponent = value["opponent"]
                @game_players.opponent.name = opponent
                @opponent_name = opponent
            
                if not @local_created
                    @local_joined = true
                
            @render_players()
        
            # Second player is here, start the countdown
            if opponent.length != 0
                @render_countdown()
            
        return
        
    # Shown once server sends player pairing results
    render_players: () ->        
        $("#game_lobby_counter").html("Waiting for another player...")
        $("#game_lobby_player_vs_text").html("VS")
        
        local_name = @data_bus.databus_request_variable("local_name")
        @game_players.local.name = local_name
        @local_name = local_name
        
        if @local_joined
            @game_players.local.color = "white"
            @game_players.opponent.color = "black"
            
            $("#game_lobby_player_left_text").html(@opponent_name)
            $("#game_lobby_player_right_text").html(@local_name)
        else
            @game_players.local.color = "black"
            @game_players.opponent.color = "white"
            
            $("#game_lobby_player_left_text").html(@local_name)
            $("#game_lobby_player_right_text").html(@opponent_name)
            
        return
            
    # Display countdown
    render_countdown: () ->
        counter = 3
        $("#game_lobby_counter").html("Game starts in ")
        interval = setInterval(=>
            if counter < 1 # Don't draw '0...'
                if counter == 0
                    clearInterval(interval)
                    @raise_event("game_lobby_done")
                return
                
            $("#game_lobby_counter").append("#{counter}...")
            counter--;
        , @countdown_interval)
        
        return
        