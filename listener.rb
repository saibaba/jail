require 'socket'

trap('TERM') {
  puts "Listerner got request to shutdown!"
  exit 0;
}

def listener_main(command_port)

  puts "Listener started... on port #{command_port}"
  s = TCPServer.new('', command_port)


  done = false
 
  while not done do

    begin
      client = s.accept
      Thread.new { puts "child thread:"; work(client) }
      puts "launched a child thread..."
    rescue
      done = true
    end
  end

  puts "Terminating listener ..."
  s.close unless s.nil?

end

def work(client)
 
    begin
      puts "Lstener waiting to recv..."
      data =  client.recv(124);
      data.chomp!

      puts "RECEIVED: #{data}"

      if (data == "SIGTERM")
        puts "My pid = #{Process.pid} and parent_pid = #{Process.ppid}"
        puts "Killing container and assuming its pid = 1..."
        Process.kill("TERM", 1)
        client.send("Sent TERM to init!", 0)
        done = true
      elsif (data == "SIGUSR1")
        puts "SIGUSR1 container..."
        puts "My pid = #{Process.pid} and parent_pid = #{Process.ppid}"
        Process.kill("USR1", 1)
        client.send("Sent USR1 to init!", 0)
        done = true
      elsif (data == "SHTTPD") 
        puts "Starting  httpd..."
        `/usr/sbin/httpd -k start`
        client.send("Started httpd!", 0)
      elsif (data == "THTTPD")
        puts "Stopping  httpd..."
        `/usr/sbin/httpd -k stop`
        client.send("Stopped httpd!", 0)
      else
        puts "Running command: #{data}"
        output = IO.popen(data)
        output.each { |l|
          client.send(l,0)
        }
        output.close
      end
    
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect 
      client.send(e.message, 0)
    ensure
      client.close
    end
end

#listener_main
