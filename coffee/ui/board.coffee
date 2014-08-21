
class Board extends View
    constructor: (@parent, @data_bus) ->
        @game_players = null
        @game_score = {"black": 0, "white": 0}
        
        @board = [\
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        ]
        
        # Remember board situation if we have to rollback
        @last_board = @board
        
        @register_commands = ["player_move", "player_move_confirm", ]
        @register_variables =
            "game_score": => return @game_score,
        @register_events =
            "player_move": [],
            "player_move_confirm": [],
            
        @messages = null: null
        
        super("board")
        
        @board_image = $("<img id='board_image' src='img/board.gif'>")

        @board_click_layer = $("<div id='board_click_layer'>")
        .click((e) => @local_move(e.pageX, e.pageY))
        
        @main_element
        .append(@board_click_layer)
        .append(@board_image)
        
        @data_bus.databus_subscribe_to_event("end_game_display", @)
        
        return
        
    init: ->
        @game_players = @data_bus.databus_request_variable("game_players")
        
        @do_move(3, 3, "white")
        @do_move(4, 3, "black")
        @do_move(3, 4, "black")
        @do_move(4, 4, "white")
        
        return
        
    receive_command: (command, value) ->
        # Opponent's move
        if command == "player_move"
            move_x = value.x
            move_y = value.y
        
            # Do captures and the actual move
            captures = @get_captures([move_x, move_y], @game_players.opponent.color)
            for c in captures
                @do_move(c[0], c[1], @game_players.opponent.color)
                
            @do_move(move_x, move_y, @game_players.opponent.color)
            
            @count_score()
            
            @raise_event("player_move", value)
            
        # Local player's move confirm
        # TODO: Error code when coordinates missing in the move sent
        else if command == "player_move_confirm"
            if value["error"] != 0
                @rollback()
                return
                
            @count_score()
            
            # Game status wants to know about this
            @raise_event("player_move_confirm", value)
                        
        return

    event_notify: (event_name) ->
        if event_name == "end_game_display"
            @deactivate_board()

    # Prevent from adding pieces on the board and hovering
    # TODO: Hovering :-) (and why not disable double clicking board too while you're at it?)
    deactivate_board: ->
        @board_click_layer.unbind("click")
        @board_click_layer.click(false)
        return
        
    # Rollback to the last move
    rollback: ->
        # TODO: This method
        @count_score()
        return
    
    count_score: ->
        black = 0
        white = 0
        for y of @board
            row = @board[y]
            
            for x of row
                if row[x] != 0
                    if row[x].hasClass("black")
                        black++;
                    else
                        white++;
        @game_score.black = black
        @game_score.white = white

        return
    
    # Validate local player's move
    local_move: (x, y) ->
        # Is it local player's turn?
        turn = @data_bus.databus_request_variable("game_turn")
        console.log("TURN IS", turn)
        if turn != "local"
            return
            
        coords = @element_to_board_coordinates(x, y)
        
        # A piece already on the clicked spot
        if @board[coords[1]][coords[0]] != 0
            return
        
        turn_color = @game_players[turn].color
        
        # Any captures from the clicked spot?
        captures = @get_captures(coords, turn_color)
        if captures.length == 0
            return
            
        # Do the move and captures
        @do_move(coords[0], coords[1], turn_color)
        
        for c in captures
            @do_move(c[0], c[1], turn_color)
        
        # Send move to the server
        @send_command({"player_move": {"x": coords[0], "y": coords[1]}})
        
        @count_score()
        
        @raise_event("player_move")
        
        return
        
    # Convert click coordinates to board coordinates
    element_to_board_coordinates: (x, y) ->
        board_x = Math.floor(x/(@board_image.width()/8));
        board_y = Math.floor(y/(@board_image.height()/8));
        
        return [board_x, board_y]

    board_to_element_coordinates: (x, y) ->
        return [x*(@board_image[0].width/8)-10+1*x, y*(@board_image[0].width/8)-10+1*y]
    
    do_move: (x, y, color) ->
        console.log("Do move",x,y)
        coords = @board_to_element_coordinates(x, y)
        
        # Create the game piece
        piece = $("<img class='board_piece #{color}'>")
        piece.attr("src", "img/#{color}.png")
        
        element_x = coords[0]
        element_y = coords[1]
        
        # TODO: left, top don't work if window resize
        piece.css({
            "left": "#{element_x}px",
            "top": "#{element_y}px",
            "width": "21%",
            "height": "auto",
        })

        @main_element.append(piece)
        
        # Remember board state in case of rollback
        @last_board = @board
        
        # Remove old piece from the board if any and insert the new one
        if @board[y][x] != 0
            @board[y][x].remove()
        @board[y][x] = piece
        
        return
                
    # Get captures caused by a move
    get_captures: (board_coordinates, turn_color) ->
        # Opponent's color from the mover's perspective
        if turn_color == "black"
            opponent_color = "white"
        else
            opponent_color = "black"
            
        x = board_coordinates[0]
        y = board_coordinates[1]
        
        captured = []
        
        # Go through eight directions around the given coordinates
        move_x = move_y = [-1,0,1]
        for i of move_x
            for j of move_y
                dir_x = move_x[i]
                dir_y = move_y[j]
                
                if dir_x == 0 && dir_y == 0
                    continue
                
                capturable = []
                current_piece = null
                counter = 1
                
                # Get all the opponent pieces in a row in one direction
                while counter < 8
                    # The coordinate to look at
                    add_x = x+dir_x*counter
                    add_y = y+dir_y*counter
                    
                    # Out of the board?
                    if add_x > 7 || add_x < 0 || add_y > 7 || add_y < 0
                        break
                        
                    current_piece = @board[add_y][add_x]
                    
                    # Continue while it's opponent's piece
                    if current_piece != 0 && current_piece.hasClass(opponent_color)
                        capturable[capturable.length] = [add_x, add_y]
                    else
                        break
                        
                    counter++
                    
                # Last piece must be player's to allow capture
                if not current_piece || current_piece == 0 || not current_piece.hasClass(turn_color)
                    continue
                                    
                for c of capturable
                    captured[captured.length] = capturable[c]
                    
        return captured
        