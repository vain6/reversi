
class UI extends View
    constructor: (@socket) ->
        @game_area = $("#game_area")
        
        @registered_commands = {}
        @registered_events = {}
        @registered_variables = {}
        @pending_events = {}
        
        super("ui")
        
        @name_input_view = new NameInput(@, @)
        @game_lobby_view = null
        @game_view = null
        
        interval = setInterval(=>
            if not @socket
                return
                
            state = @socket.get_connection()
            
            if state == 3
                console.log("Connecting...")
                @socket.createConnection()
                
            else if state == 1
                clearInterval(interval)
                @init_instances()
                @set_state(0)
        , 1000)
        
        return
        
    init_instances: ->
        @game_area.html("")
        @game_lobby_view = new GameLobby(@, @)
        @game_view = new Game(@, @)
        
        @databus_subscribe_to_event("name_input_done", @)
        @databus_subscribe_to_event("game_lobby_done", @)
        @databus_subscribe_to_event("game_view_done", @)
        
        return
    
    set_socket: (socket) ->
        @socket = socket
        return
    
    set_state: (state) ->
        if state == 0
            @name_input_view.render(@game_area, true)
        else if state == 1
            @game_lobby_view.render(@game_area)
        else if state == 2
            @game_view.render(@game_area)
        return
        
    event_notify: (event_name) ->
        if event_name == "name_input_done"
            @set_state(1)
        else if event_name == "game_lobby_done"
            @set_state(2)
        else if event_name == "game_view_done"
            @init_instances()
            @set_state(1)
            
        return
        
    # ==================================== 
    # Here starts data bus related methods
    # ====================================
    
    #
    # Registered command handling
    #
    databus_register_command: (command, source) ->
        @registered_commands[command] = source
        return

    receive_command: (command, source) ->
        for cmd,value of command
            key = @registered_commands[cmd]
            if key
            	key.receive_command(cmd, value)
        return
        
    send_command: (command) ->
        @socket.sendCommand(command)
        return
        
    #
    # Registered variable handling
    #
    databus_register_variable: (var_name, source) ->
        @registered_variables[var_name] = source
        return
        
    databus_request_variable: (var_name) ->
        if not @registered_variables.hasOwnProperty(var_name)
            return false
        
        return @registered_variables[var_name].request_variable(var_name)
        
    #
    # Registered event handling
    #
    databus_register_event: (event_name, source) ->
        @registered_events[event_name] = source
        
        # Any pending subscribers for this event?
        if @pending_events.hasOwnProperty(event_name)
            for i of @pending_events[event_name]
                @databus_subscribe_to_event(event_name, @pending_events[event_name][i])
                
            delete @pending_events[event_name]
        
        return
                
    databus_subscribe_to_event: (event_name, target) ->
        if not @registered_events.hasOwnProperty(event_name)
            # If there is no event owner
            if @pending_events.hasOwnProperty(event_name)
                targets = @pending_events[event_name]
                targets[targets.length] = target
                @pending_events[event_name] = targets
            else
                @pending_events[event_name] = [target]
                
            return false
            
        @registered_events[event_name].subscribe_to_event(event_name, target)
        return
        