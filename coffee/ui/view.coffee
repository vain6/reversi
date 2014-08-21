
class window.View
    constructor: (element) ->
        @main_element = $("<div id='#{element}'>")
        
        @register_commands_to_databus()
        @register_variables_to_databus()
        @register_events_to_databus()
        
        return
    
    # Render this view to target element
    render: (target_element, append=false) ->
        if append == true
            target_element.append(@main_element)
        else
            target_element.html(@main_element)
            
        @init()
        
        return
        
    # Other functions useful to run while rendering
    init: ->
    
    #
    # Registrable command handling
    #
    # Register commands to the data bus
    register_commands_to_databus: ->
        if not @register_commands
            return
        for command in @register_commands
            @data_bus.databus_register_command(command, @)
        return
        
    # Prototype method classes should implement to handle server responses
    receive_command: (command, value) ->
    
    send_command: (command) ->
        @data_bus.send_command(command)
    
    #
    # Registrable variable handling
    #
    # Register variables to the data bus
    register_variables_to_databus: ->
        if not @register_variables
            return
            
        for v of @register_variables
            @data_bus.databus_register_variable(v, @)
            
        return
        
    # Return requested variable value to the asker
    request_variable: (variable) ->        
        if not @register_variables.hasOwnProperty(variable)
            return false
                        
        return @register_variables[variable]()
        
    #
    # Registrable events handling
    #
    # Register events to the data bus
    register_events_to_databus: ->
        if not @register_events
            return
        
        for e of @register_events
            @data_bus.databus_register_event(e, @)
        
    # Views can subscribe to be notified about events
    subscribe_to_event: (event_name, target) ->
        key = @register_events[event_name]
        key[key.length] = target
        return
        
    # Loop through subscribed objects to notify them about the event
    raise_event: (event_name, data=null) ->
        for s in @register_events[event_name]
            s.event_notify(event_name, data)
            
    # Prototype method classes should implement to handle incoming events
    event_notify: (event_name) ->
    