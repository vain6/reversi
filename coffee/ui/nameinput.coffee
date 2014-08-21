
class NameInput extends View
    constructor: (@parent, @data_bus) ->
        @local_name = null;
        
        @register_commands = ["set_name",]
        @register_variables =
            "local_name": => return @local_name, # Function to return value
        @register_events =
            "name_input_done": [],
            
        @messages =
            "-1": "Name must be 0-10 characters long.",
            
        super("name_input")

        @name_field = $("<input id='name_input_form_field' placeholder='Your name here...'>")
        @name_ok = $("<input id='name_input_form_button' class='button' type='button' value='Submit'>")
        .click => @validate_name()
        name_form = $("<div id='name_input_form'>")
        .append(@name_field, @name_ok)
        
        @error_element = $("<div id='name_input_errors'>")
        
        name_input_text = $("<div id='name_input_text'>\
            <h2 id='name_input_html5' class='impact'>HTML5</h2>\
            <h2 id='name_input_reversi' class='lobster'>Reversi</h2>\
        </div>")
        
        name_input = $("<div id='name_input_banner'>")
        .append(name_input_text)
        .append(name_form)
        .append(@error_element)
        
        @main_element
        .append(name_input)
        
        return
        
    # Local name validation
    validate_name: ->
        length = @name_field.val().length
        
        if length > 0 and length < 16
            @clear_error()
            
            # Disable field while waiting for a response
            @name_field.attr("disabled", "disabled")
            @name_ok.attr("disabled", "disabled")
            
            @send_command({"set_name": {"name": @name_field.val()}})
        else
            @render_error(-1)
        return
        
    # Server validation results directed here
    # Only one command so no reason to do any have methods
    receive_command: (command, value) ->
        console.log("Name validation from the server")
        if value["error"] != 0
            @render_error(value["error"])
            @name_field.removeAttr("disabled")
            @name_ok.removeAttr("disabled")
            return
            
        @local_name = @name_field.val()
        
        # Taking names is done for ever
        @raise_event("name_input_done")
        
        return
                
    render_error: (code) ->
        @error_element.html(@messages[code])
        return
        
    clear_error: ->
        @error_element.html("")
        return
        