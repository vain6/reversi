
class ClientWebSocket
    constructor: (@onMessageCallback) ->
        @host = "ws://html5reversi:10000"
        @createConnection()
        
        return

    get_connection: ->
        return @websocket.readyState
        
    createConnection: ->
        @websocket = new WebSocket(@host)
        @websocket.onmessage = (e)  => @receive_command(e, @onMessageCallback)
        @websocket.onopen = @onOpen
        @websocket.onclose = @onClose
        @websocket.onerror = @onError
        return

    sendCommand: (message) ->
        console.log("Sending:")
        console.log("  ",JSON.stringify(message))
        @websocket.send(JSON.stringify(message))
        return
        
    receive_command: (e, callback) ->
        console.log('Response:')
        console.log("  ",e.data)
        try
            data = JSON.parse(e.data)
        catch e
            console.error("Could not parse server message!")
            return
            
        callback.receive_command(data);
            
        return
        
    closeConnection: ->
        @websocket.close()
        console.log("Connection closed")
        return
        
    onOpen: (e) ->
        console.log("Connection created")
        return
    onClose: (e) ->
        console.log("Disconnected")
        return
    onError: (e) ->
        console.log("ERROR #{e.data}")
        return
        