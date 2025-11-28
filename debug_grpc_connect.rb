require 'grpc'
$LOAD_PATH.unshift(File.expand_path('gateway/app/lib/protos', __dir__))
require 'msg_services_pb'

def test_connection
  puts "Attempting to connect to 127.0.0.1:50051..."
  
  stub = Protocol::GameServerService::Stub.new(
    '127.0.0.1:50051',
    :this_channel_is_insecure
  )

  puts "Stub created. Checking connectivity..."
  
  # Try to wait for ready (timeout 5 seconds)
  begin
    state = stub.check_connectivity
    puts "Initial connectivity state: #{state}"
    
    # This might block if server is silent
    # We can't easily force a handshake without making a call, 
    # but waitForReady might trigger it.
    
    # Let's try to make a dummy call if possible, or just print state.
    # Since it's a streaming service, we can't make a simple unary call.
    # But we can try to start a stream.
    
    puts "Starting stream..."
    requests = Enumerator.new { |y| y << Protocol::G2G_Message.new(protocol_id: 0, data: "") }
    responses = stub.player_session(requests)
    
    puts "Stream started. Waiting for response (will likely fail as we sent garbage)..."
    responses.each do |r|
      puts "Received response: #{r.inspect}"
      break
    end
    
  rescue GRPC::Unavailable => e
    puts "GRPC Unavailable: #{e.message}"
    puts "Debug error string: #{e.debug_error_string}"
  rescue => e
    puts "Error: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n")
  end
end

test_connection
