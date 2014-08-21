
class GameStatus extends View
    constructor: (@parent, @data_bus) ->
        @game_turn = null
        @game_players = null
        @turn_timer = null
        
        # Remember last turn if we have to rollback
        @last_turn = {"turn": null, "timer": null}
        
        @register_commands = ["end_game",]
        @register_variables =
            "game_turn": => return @game_turn,
        @register_events =
            "end_game_display": [],
            "end_game": [],
        
        @messages =
            1: "Your opponent just resigned",
            2: "No moves left",
            3: "Opponent's timer ran out",
            4: "Your timer ran out",
            5: "No moves left", # Same as 2 but means losing
            6: "No moves left", # Same as 2 but tie
            7: "Opponent connection lost",
            
        super("game_status")
        
        @status_black_name = $("<span id='game_status_black_name'>")
        @status_black_score = $("<span id='game_status_black_score'>0</span>")
        @status_black = $("<div id='game_status_black' class='border impact'>")
        .append(@status_black_name)
        .append(@status_black_score)
        
        @status_white_name = $("<span id='game_status_white_name'>")
        @status_white_score = $("<span id='game_status_white_score'>0</span>")
        @status_white = $("<div id='game_status_white' class='border impact'>")
        .append(@status_white_name)
        .append(@status_white_score)
        
        @status_message_text = $("<div id='game_status_text' class='impact'>")
        @status_message_timer = $("<div id='game_status_timer' class='lobster'>")
        @status_message = $("<div id='game_status_message' class='border'>")
        .append(@status_message_text)
        .append(@status_message_timer)
        
        @end_game_button = $("<input class='button' type='button' value='Resign'>")
        .click(=> @resign())
        @status_button = $("<div id='game_status_button'>")
        .append(@end_game_button)
        
        @main_element
        .append(@status_black)
        .append(@status_white)
        .append(@status_message)
        .append(@status_button)
        
        @data_bus.databus_subscribe_to_event("player_move", @)
        @data_bus.databus_subscribe_to_event("player_move_confirm", @)
        
        return
        
    init: ->
        # Fill in UI boxes and fill game turn
        @game_players = @data_bus.databus_request_variable("game_players")
        
        if @game_players.local.color == "black"
            @status_black_name.html(@game_players.local.name)
            @status_white_name.html(@game_players.opponent.name)
            @game_turn = "local"
        else
            @status_black_name.html(@game_players.opponent.name)
            @status_white_name.html(@game_players.local.name)
            @game_turn = "opponent"
            
        @start_turn()
        
        return

    event_notify: (event_name, data) ->
        if @game_players.local.color == data["turn"]
            @game_turn = "local"
        else
            @game_turn = "opponent"
            
        if event_name == "player_move"            
            @render_score()
            
            # Refresh UI for the opponent only
            if @game_turn == "local"
                @start_turn()
            
        # Refresh UI for the local when the move if confirmed
        else if event_name == "player_move_confirm"
            @start_turn()
            
        return
        
    receive_command: (command, value) ->
        if command == "end_game"
            r = value.reason
            
            # Winning codes
            if r in [1,2,3,7]
                winner = @game_players.local.color
            # Losing codes
            else if r in [4,5]
                winner = @game_players.opponent.color
            # Tie
            else if r == 6
                winner = false
                
            @end_game_display(value.reason, winner)
            
        return
            
    render_score: ->
        game_score = @data_bus.databus_request_variable("game_score")
        @status_white_score.html(game_score.white)
        @status_black_score.html(game_score.black)
        return
        
    start_turn: () ->
        # Clear UI
        @status_black.removeClass("game_status_highlight")
        @status_white.removeClass("game_status_highlight")
        
        @status_message_text.html("")
        @status_message_timer.html("")
        
        clearInterval(@turn_timer)
            
        if @game_turn == "local"
            turn_text = "Your turn"
            if @game_players.local.color == "black" 
                @status_black.addClass("game_status_highlight")
            else
                @status_white.addClass("game_status_highlight")
        else
            turn_text = "Opponent's turn"
            if @game_players.opponent.color == "black" 
                @status_black.addClass("game_status_highlight")
            else
                @status_white.addClass("game_status_highlight")
                
        @render_score()
        
        @status_message_text.html(turn_text)
        @status_message_timer.html("Time left: 60")
        @start_timer()
        
        return
        
    start_timer: ->
        timer = 60
        clearInterval(@turn_timer)
        
        @turn_timer = setInterval(=>
            timer--
            @status_message_timer.html("Time left: #{timer}")
            
            if timer == 0
                clearInterval(@turn_timer)
                # TODO: Raise event/whatever
        , 1000)
        
        return
        
    resign: ->
        @send_command({"end_game": {"reason": 1}})
        @raise_event("end_game")
        return
        
    end_game_display: (reason, winner) ->
        @raise_event("end_game_display")
        
        @render_score()
        @status_black.removeClass("game_status_highlight")
        @status_white.removeClass("game_status_highlight")
        
        @status_message_text.html(@messages[reason])
        
        clearInterval(@turn_timer)
        if winner == 0
            @status_message_timer.html("The game is a tie!")
        else if @game_players.local.color == winner
            @status_message_timer.html("You are victorious!")
        else
            @status_message_timer.html("You lose miserably.")
            
        @end_game_button.val("OK, got it")
        @end_game_button.unbind("click")
        @end_game_button.click(=> @end_game_confirm())
        
        return
        
    # User clicks OK after declaring game end    
    end_game_confirm: ->
        @send_command({"return_lobby": {"": ""}})
        @raise_event("end_game")
        return
        