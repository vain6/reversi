#!/usr/local/bin/php -q
<?php
error_reporting(E_ALL);
set_time_limit(0);
ob_implicit_flush();

define("STATE_NO_NAME", 0);
define("STATE_NAME_GIVEN", 1);
define("STATE_LOBBY_ALONE", 2);
define("STATE_LOBBY_ALL", 3);
define("STATE_GAME_STARTED", 4);
define("STATE_GAME_ENDED", 5);

// IP address may be given as an argument
$host = 'localhost';
if (sizeof($argv) > 1)
    $host = $argv[1];
$socket = new WebSocket($host);

class WebSocket {
    private $host;
    private $port = 10000;
    private $master_socket;
    private $sockets = array();
    private $game_controller;
    private $narrator;
    
    function __construct($host='localhost') {
        echo "Starting HTML5 Reversi server!\nHost: ".$host."\n";
        $this->host = $host;
        
        $this->narrator = new Narrator();
        $this->game_controller = new GameController($this);
        
        if ($this->create_server() === TRUE)
            $this->main_loop();
    }
    
    private function main_loop() {
        
        while (TRUE) {
            // Get the changed sockets
            $changed = $this->sockets;
            
            if (@socket_select($changed, $write = NULL, $except = NULL, 0) >= 1) {
                foreach($changed as $socket) {
                    // Connection to the main socket or a request from a user
                    if ($socket === $this->master_socket)
                        $this->add_client($socket);
                    else {
                        $bytes = socket_recv($socket, $buffer, 2048, 0);
                        // Connection hangs
                        if ($bytes == 8)
                            $this->close_connection($socket);
                        else
                            $this->parse_client_command($socket, $buffer);
                    }
                }
            }
            // Things game wants to do every tick
            $this->game_controller->game_loop();
        }
    }
    
    private function parse_client_command($socket, $command) {
        // Open up websocket packet
        $command = $this->unmask($command);
        
        // Command may be disconnect or other message
        try {
            $command = json_decode($command, true);
        }
        catch(Exception $e) {
            echo "Got exception ".$e;
            return;
        }
        
        if ($command == null)
            return;
        
        foreach($command as $name => $value) {
            $this->narrator->say("Command received: ".$name);
        }
        
        $this->game_controller->client_command($socket, $command);
    }
    
    private function add_client($socket) {

        $new_socket = socket_accept($socket);
        
        if ($this->do_handshake($new_socket) === TRUE) {
            $this->narrator->say("New client");
            array_push($this->sockets, $new_socket);
            $this->game_controller->create_player($new_socket);
        }
    }
    
    // Unmask the Websocket packet
    private function unmask($text) {
        $length = ord($text[1]) & 127;
        if($length == 126) {
            $masks = substr($text, 4, 4);
            $data = substr($text, 8);
        }
        elseif($length == 127) {
            $masks = substr($text, 10, 4);
            $data = substr($text, 14);
        }
        else {
            $masks = substr($text, 2, 4);
            $data = substr($text, 6);
        }
        $text = "";
        for ($i = 0; $i < strlen($data); ++$i) {
            $text .= $data[$i] ^ $masks[$i%4];
        }
        return $text;
    }
    
    // Mask the packet into Websocket form
    private function mask($text)
    {
        $b1 = 0x80 | (0x1 & 0x0f);
        $length = strlen($text);
    
        if($length <= 125)
            $header = pack('CC', $b1, $length);
        elseif($length > 125 && $length < 65536)
            $header = pack('CCn', $b1, 126, $length);
        elseif($length >= 65536)
            $header = pack('CCNN', $b1, 127, $length);
        return $header.$text;
    }
    
    private function create_server() {
        $success = TRUE;
        $socket = @socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
    
        if ($socket === FALSE) {
            echo "Socket creation failed: ".socket_strerror(socket_last_error())."\n";
            $success = FALSE;
        }
        elseif (@socket_bind($socket, $this->host, $this->port) === FALSE) {
            echo "Socket binding failed: ".socket_strerror(socket_last_error($socket))."\n";
            $success = FALSE;
        }
        elseif (@socket_listen($socket, 5) === FALSE) {
            echo "Socket listening failed: " . socket_strerror(socket_last_error($socket))."\n";
            $success = FALSE;
        }
        
        if ($success === TRUE) {
            $this->master_socket = $socket;
            array_push($this->sockets, $this->master_socket);
        }
        return $success;
    }
    
    // New client handshake
    private function do_handshake($socket) {
        $raw_headers = socket_read($socket, 1024);
    
        $headers = array();
        $lines = preg_split("/\r\n/", $raw_headers);
        unset($lines[0]); // Contains "GET / HTTP/1.1"

        foreach($lines as $line)
        {
            $value = explode(": ", $line);
            if (sizeof($value) == 2)
                $headers[$value[0]] = $value[1];
        }
            
        // Send back Websocket handshake
        $secAccept = base64_encode(pack('H*', sha1($headers['Sec-WebSocket-Key'].'258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
        $handshake  = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" .
        "Upgrade: websocket\r\n" .
        "Connection: Upgrade\r\n" .
        "WebSocket-Origin: $this->host\r\n" .
        "WebSocket-Location: ws://$this->host:$this->port\r\n".
        "Sec-WebSocket-Accept:$secAccept\r\n\r\n";
        
        return $this->send_data($socket, $handshake);
    }

    public function send_data($socket, $data) {
        if (is_array($data))
            $data = json_encode($data);

        $data = $this->mask($data);
        
        // Returns TRUE/FALSE depending on write success
        if (socket_write($socket, $data, strlen($data)) > 0)
            return TRUE;
        return FALSE;
    }

    private function close_connection($socket) {
        $this->narrator->say("Closing connection");
        socket_close($socket);
        unset($this->sockets[array_search($socket, $this->sockets)]);
        
        $this->game_controller->remove_player_by_socket($socket);
    }
}

class Player {
    private $socket;
    private $name;
    private $game_state = STATE_NO_NAME;
    
    function __construct($socket) {
        $this->socket = $socket;
    }
    
    public function set_name($name) {
        if ($this->name == NULL) {
            $this->name = $name;
            $this->game_state = STATE_NAME_GIVEN;
        }
    }
    
    public function get_name() {
        return $this->name;
    }
    
    public function get_socket() {
        return $this->socket;
    }
    
    public function get_game_state() {
        return $this->game_state;
    }
    
    public function set_game_state($state) {
        $this->game_state = $state;
    }
}

class Game {
    private $players = array();
    
    private $board = array(
        array(3,3,3,3,3,3,3,3),
        array(3,3,3,3,3,3,3,3),
        array(3,3,3,3,3,3,3,3),
        array(3,3,3,1,0,3,3,3),
        array(3,3,3,0,1,3,3,3),
        array(3,3,3,3,3,3,3,3),
        array(3,3,3,3,3,3,3,3),
        array(3,3,3,3,3,3,3,3),
    );
    
    private $timer_end = null;
    private $default_timer = 60;
    private $turn = 0;
    private $is_started = FALSE;
    
    function __construct($player_one, $player_two) {
        array_push($this->players, $player_one, $player_two);
    }
    
    public function add_player($player) {
        if ($this->players[0] == null OR $this->players[1] == null)
            $this->players[1] = $player;
    }
    
    public function get_is_started() {
        return $this->is_started;
    }
    
    // First timer round includes the lobby countdown
    public function start_timer() {
        $this->timer_end = microtime(TRUE) + $this->default_timer + 4;
        $this->is_started = TRUE;
    }
    
    public function do_move($coordinates) {
        $this->timer_end = microtime(TRUE) + $this->default_timer;
        $this->board[$coordinates[1]][$coordinates[0]] = $this->turn;
    }
    
    public function is_empty_coordinate($coordinates) {
        if ($this->board[$coordinates[1]][$coordinates[0]] == 3)
            return TRUE;
        return FALSE;
    }
    
    public function count_score() {
        $score = array(0,0);
        for ($y=0; $y<8; $y++) {
            for ($x=0; $x<8; $x++) {
                $symbol = $this->board[$y][$x];
                if ($symbol < 3)
                    $score[$symbol]++;
            }
        }
        return $score;
    }
    
    public function switch_turn() {
        if ($this->turn == 0)
            $this->turn = 1;
        else
            $this->turn = 0;
    }
    
    public function has_player($player) {
        if ($this->players[0] === $player OR $this->players[1] === $player)
            return TRUE;
        return FALSE;
    }
    
    public function get_players() {
        return $this->players;
    }
    
    public function get_opponent($player) {
        if ($this->players[0] === $player)
            return $this->players[1];
            
        else if ($this->players[1] === $player)
            return $this->players[0];
            
        return FALSE;
    }
    
    public function is_time_out() {
        if (microtime(TRUE) > $this->timer_end)
            return TRUE;
        return FALSE;
    }
    
    public function get_turn_player() {
        return $this->players[$this->turn];
    }
    
    public function get_turn() {
        return $this->turn;
    }
    
    public function get_turn_color() {
        if ($this->turn == 0)
            return "black";
        return "white";
    }
        
    // Get captures for a given move
    // Directly translated from the CoffeeScript implementation
    public function get_captures($coordinates, $turn) {
        if ($turn == 0)
            $opponent = 1;
        else
            $opponent = 0;
    
        $x = $coordinates[0];
        $y = $coordinates[1];
    
        $captured = array();
    
        $move_x = $move_y = array(-1, 0, 1);
    
        // Go through eight directions around the given coordinates
        for ($i=0; $i<sizeof($move_x); $i++) {
            for ($j=0; $j<sizeof($move_y); $j++) {
                $dir_x = $move_x[$i];
                $dir_y = $move_y[$j];
            
                if ($dir_x == 0 AND $dir_y == 0)
                    continue;
                
                $capturable = array();
                $current_piece = 0;
                $counter = 1;

                // Get all the opponent pieces in a row in one direction
                while ($counter < 8) {
                    // The coordinate to look at
                    $add_x = $x+$dir_x*$counter;
                    $add_y = $y+$dir_y*$counter;
                
                    // Out of the board?
                    if ($add_x > 7 OR $add_x < 0 OR $add_y > 7 OR $add_y < 0)
                        break;
                        
                    $current_piece = $this->board[$add_y][$add_x];
                    
                    // Continue while it's opponent's piece
                    if ($current_piece == $opponent)
                        array_push($capturable, array($add_x, $add_y));
                    else
                        break;
                    
                    $counter++;
                }
                
                // Last piece must be player's to allow capture
                if ($current_piece != $turn)
                    continue;
                    
                foreach ($capturable as $c)
                    array_push($captured, $c);
            }
        }
                
        return $captured;
    }

    public function get_all_captures($turn) {
        $all_captures = array();
        for ($y = 0; $y<8; $y++) {
            for ($x = 0; $x<8; $x++) {
                $move = array($x, $y);
                
                if (!$this->is_empty_coordinate($move))
                    continue;
                
                $captures = $this->get_captures($move, $turn);
                foreach ($captures as $c) {
                    if (!in_array($c, $all_captures))
                        array_push($all_captures, $c);
                }
            }
        }
        return $all_captures;
    }
}

class GameController {
    private $games = array();
    private $players = array();
    private $commands = array("set_name", "player_move", "end_game", "return_lobby");
    private $connection;
    private $narrator;
    
    function __construct($connection) {
        $this->narrator = new Narrator();
        $this->connection = $connection;
    }
    
    public function game_loop() {
        $this->match_players();
        $this->check_game_timers();
    }
    
    private function create_game($player_one, $player_two=null) {
        $new_game = new Game($player_one, $player_two);
        array_push($this->games, $new_game);
        return $new_game;
    }
    
    public function create_player($socket) {
        $player = new Player($socket);
        array_push($this->players, $player);
    }
    
    public function remove_player_by_socket($socket) {
        $player = $this->get_player_by_socket($socket);        
        $this->remove_player($player);
        
        // The player may have a game open
        if ($player->get_game_state() < STATE_LOBBY_ALONE)
            return;
        
        // Get the opponent and send a notification
        $game = $this->get_player_game($player);
        
        if ($game == null)
            return;
        
        $opponent = $game->get_opponent($player);
        $this->send_end_game_data($opponent, null, 7, null);
        
        $opponent->set_game_state(STATE_GAME_ENDED);
        
        $this->remove_game($game);
    }
    
    public function remove_player($player) {
        unset($this->players[array_search($player, $this->players)]);
    }
    
    private function remove_game($game) {
        unset($this->games[array_search($game, $this->games)]);
    }
    
    private function match_players() {
        // Get players with the right state
        $available = array();
        foreach ($this->players as $player) {
            $state = $player->get_game_state();
            if ($state == STATE_NAME_GIVEN OR $state == STATE_LOBBY_ALONE)
                array_push($available, $player);
        }
        
        // Go through available players again and match them
        for ($i=0; $i<sizeof($available); $i+=2) {
            $player_one = $available[$i];
            @$player_two = $available[$i+1];
            
            // Create a new game for the remaining player
            if ($player_two == NULL) {
                $state = $player_one->get_game_state();
                if ($state == STATE_NAME_GIVEN) {
                    $this->narrator->say("Creating a new game".$player->get_name());
                    $game = $this->create_game($player_one);
                    $this->send_new_game_data($player_one);
                }
                break;
            }
            
            $this->narrator->say("Game players:");
            $this->narrator->say($player_one->get_name(), 1);
            $this->narrator->say($player_two->get_name(), 1);
            
            $game = $this->get_player_game($player_one);
            if ($game === FALSE) {
                $game = $this->get_player_game($player_two);
                $game->add_player($player_one);
            }
            else
                $game->add_player($player_two);
                  
            $game->start_timer();
                        
            // Inform players about the new game (one is already in the game)
            $this->send_new_game_data($player_one, $player_two);
            $this->send_new_game_data($player_two, $player_one);
        }
    }
    
    // Check if there are expired game timers
    private function check_game_timers() {
        foreach ($this->games as $game) {
            if ($game->is_time_out() === FALSE || $game->get_is_started() === FALSE)
                continue;
                                        
            // Get game loser/winner, prepare data and send it
            $loser = $game->get_turn_player();
            $winner = $game->get_opponent($loser);
            
            $winner_reason = 3;
            $loser_reason = 4;
                        
            $this->send_end_game_data($winner, $loser, $winner_reason, $loser_reason);
        }
    }
    
    public function send_end_game_data($player_one, $player_two, $player_one_reason, $player_two_reason) {
        if ($player_one != null) {
            $player_one_data = array("end_game" => array("reason" => $player_one_reason));
            $this->connection->send_data($player_one->get_socket(), $player_one_data);
            $player_one->set_game_state(STATE_GAME_ENDED);
        }
        if ($player_two != null) {
            $player_two_data = array("end_game" => array("reason" => $player_two_reason));
            $this->connection->send_data($player_two->get_socket(), $player_two_data);
            $player_two->set_game_state(STATE_GAME_ENDED);
        }
        
        $game = $this->get_player_game($player_one);
        $this->remove_game($game);
    }
    
    private function send_new_game_data($player, $opponent=null) {
            if ($opponent == null) {
                $opponent = "";
                $player->set_game_state(STATE_LOBBY_ALONE);
            }
            else {
                $opponent = $opponent->get_name();
                $player->set_game_state(STATE_LOBBY_ALL);
            }
            
            $player_game_data = array("lobby_players" => array("opponent" => $opponent));
            $player_game_data = json_encode($player_game_data);
            $this->connection->send_data($player->get_socket(), $player_game_data);
    }
    
    public function get_player_game($player) {
        foreach ($this->games as $game) {
            if ($game->has_player($player) === TRUE)
                return $game;
        }
        return FALSE;
    }
    
    public function get_player_by_socket($socket) {
        foreach ($this->players as $player) {
            if ($player->get_socket() === $socket)
                return $player;
        }
        return FALSE;
    }
    
    public function client_command($socket, $command) {
        $player = $this->get_player_by_socket($socket);
        
        if ($player === FALSE)
            return;
            
        // Run related commands for the commands
        foreach($command as $cmd => $value) {    
            if (in_array($cmd, $this->commands)) {
                $return_msg = array();
                
                if ($cmd == "set_name")
                    $cmd_return = $this->do_name($value, $player);
                    
                if ($cmd == "player_move")
                    $cmd_return = $this->do_move($value, $player);
                    
                // Resign command from player
                if ($cmd == "end_game")
                    $cmd_return = $this->do_resign($value, $player);
                    
                if ($cmd == "return_lobby")
                    $cmd_return = $this->do_return_lobby($value, $player);
                    
                // Send back errors and confirmations if wanted
                if ($cmd_return !== FALSE) {
                    $return_msg[$cmd] = $cmd_return;
                    $this->connection->send_data($socket, $return_msg); 
                }  
            }
            
            // Support for one command per request allowed
            break;
        }
    }
    
    private function do_return_lobby($value, $player) {
        $player->set_game_state(STATE_NAME_GIVEN);
        return FALSE;
    }
    
    private function do_resign($value, $player) {
        // Notify opponent
        $game = $this->get_player_game($player);
        $opponent = $game->get_opponent($player);
        $this->send_end_game_data(null, $opponent, null, 1);
        
        $player->set_game_state(STATE_NAME_GIVEN);
        $opponent->set_game_state(STATE_GAME_ENDED);
        
        return FALSE;
    }
    
    private function do_move($move, $player) {
        $game = $this->get_player_game($player);
        
        // Is it player's turn?
        if (!$game->get_turn_player() === $player)
            return FALSE;
            
        // Move coordinates exist?
        if (!array_key_exists("x", $move) OR !array_key_exists("y", $move))
            return FALSE;
            
        // Move coordinates within bounds?
        if ($move["x"] < 0 OR $move["x"] > 7 OR $move["y"] < 0 OR $move["y"] > 7)
            return FALSE;
            
        // Empty coordinate?
        if (!$game->is_empty_coordinate(array($move["x"], $move["y"])))
            return FALSE;
            
        // Any captures for the move?
        $turn = $game->get_turn();
        $cap_move = array($move["x"], $move["y"]);
        $captures = $game->get_captures($cap_move, $turn);
        
        if (sizeof($captures) == 0)
            return FALSE;
            
        // Do the move including the captures
        $game->do_move(array($move["x"], $move["y"]));
        
        foreach ($captures as $c)
            $game->do_move($c);
            
        $game->switch_turn();
        
        // Are there moves for the next turn's player?
        $turn = $game->get_turn();
        if (sizeof($game->get_all_captures($turn)) == 0) {
            $game->switch_turn(); // Switch turn back
            $turn = $game->get_turn();
            
            // Are there moves for this player either?
            if (sizeof($game->get_all_captures($turn)) == 0) {
                // Opponent still wants to know the move
                $opponent = $game->get_opponent($player);
                $return_msg = array("player_move" => array("x" => $move["x"], "y" => $move["y"]));
                $this->connection->send_data($opponent->get_socket(), $return_msg);
            
                // End the game
                $score = $game->count_score();
                
                $players = $game->get_players();
                $index = array_search($player, $players);
                
                if ($score[0] > $score[1]) {
                    if ($index == 0) {
                        $player_reason = 2;
                        $opponent_reason = 5;
                    }
                    else {
                        $player_reason = 5;
                        $opponent_reason = 2;
                    }
                }
                else if ($score[0] < $score[1]) {
                    if ($index == 0) {
                        $player_reason = 5;
                        $opponent_reason = 2;
                    }
                    else {
                        $player_reason = 2;
                        $opponent_reason = 5;
                    }
                }
                else if ($score[0] == $score[1]) {
                    $player_reason = 6;
                    $opponent_reason = 6;
                }
                
                $this->send_end_game_data($player, $opponent, $player_reason, $opponent_reason);
                
                return FALSE;
            }
                
        }
        
        $color = $game->get_turn_color();
        
        // Send confirmation to the player
        $return_msg = array("player_move_confirm" => array("error" => 0, "turn" => $color));
        $this->connection->send_data($player->get_socket(), $return_msg);
        
        // Send the move to the opponent
        $opponent = $game->get_opponent($player);
        $return_msg = array("player_move" => array("x" => $move["x"], "y" => $move["y"], "turn" => $color));
        $this->connection->send_data($opponent->get_socket(), $return_msg);
        
        return FALSE;
    }
    
    private function do_name($command, $player) {
        $return = array();
        
        // Name exists in the command?
        $error = 0;
        if (! array_key_exists("name", $command))
            $error = -1;
               
        // Validate name
        $length = strlen($command["name"]);
        if ($length == 0 OR $length > 10)
            $error = -1;
            
        if ($error == 0)
            $player->set_name($command["name"]);
        
        $return["error"] = $error;
        
        return $return;
    }
}

// A class for echoing out anything in a uniform way
class Narrator {
    public function say($input_message, $indent=0) {
        $arrow = "> ";
        if ($indent != 0)
            $arrow = "";
            
        echo str_repeat("  ", $indent).$arrow.$input_message."\n";
    }
}

?>