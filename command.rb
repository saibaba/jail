require 'socket'
host=ARGV[0]
cmd = ARGV[1]

client = TCPSocket.open(host, 5555)

client.send(cmd, 0)

answer = client.gets(nil)
puts answer

client.close

