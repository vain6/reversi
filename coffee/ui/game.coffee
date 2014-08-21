
class Game extends View
    constructor: (@parent, @data_bus) ->
        @register_commands = null
        @register_variables = null
        @register_events =
            "game_ready": [],
            "game_view_done": [],
        
        @messages =
            null: null,
            
        super("game")
        
        @game_board = new Board(@, @data_bus)
        @game_status = new GameStatus(@, @data_bus)
        
        @data_bus.databus_subscribe_to_event("end_game", @)
        
        return
        
    render: (target_element) ->
        @game_status.render(@main_element)
        @game_board.render(@main_element, true)
        target_element.html(@main_element)
        
        @raise_event("game_ready")
        
        return
        
    event_notify: (event_name) ->
        # Game ended
        console.log("Game ended!")
        @raise_event("game_view_done")
        