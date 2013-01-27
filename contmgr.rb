require 'fileutils'
require 'socket'

require './continst'
require './logging'
require './conf'

CLONE_NO=56
UNSHARE_NO = 272
CLONE_NEWNET=0x40000000

def unshare
  syscall UNSHARE_NO, CLONE_NEWNET
end

class ContainerManager
  include Logging

  attr_accessor :host_ip, :container_ip, :tenant_id, :base, :command_port
  
  def initialize
    yield self if block_given?
    @tenant_home = "#{@base}/#{@tenant_id}"
    @pipe="#{@tenant_home}/comm_pipe.fifo"
    @in_pipe="#{@tenant_home}/comm_pipe_in.fifo"
    @link_host_name="v0-tenant-#{@tenant_id}"
    @link_cont_name="v1-tenant-#{@tenant_id}"
    @pid_file = "#{@tenant_home}/var/run/init.pid"
    @etc = "#{@tenant_home}/etc"
  end

  def create_instance
    inst = ContainerInstance.new do |c|
      c.host_ip = @host_ip
      c.container_ip = @container_ip
      c.tenant_id = @tenant_id
      c.base = @base
      c.command_port = @command_port
    end

    return inst
  end

  def init_pid

    pid = nil

    if File.exist?(@pid_file) and File.file?(@pid_file)
      input = open(@pid_file, "r")
      x = input.gets
      input.close
      x.chomp!
      pid = x.to_i
    end
    return pid

  end

  def init
   
    pid = init_pid
    raise "Container already running under pid: #{pid}" unless pid.nil?

    FileUtils.rm_f(@pipe)
    FileUtils.rm_f(@in_pipe)
    `ip link del #{@link_host_name} > /dev/null 2>&1`
    `ip link del #{@link_cont_name} > /dev/null 2>&1`

    `mkfifo #{@pipe}`
    `ip link add name #{@link_host_name} type veth peer name #{@link_cont_name}`
    `ifconfig #{@link_host_name} #{@host_ip} up`
    `route add -host #{@container_ip} dev #{@link_host_name}`

    @init_pid = Process.fork {
      unshare
      child_ready
      $0 = "ruby container-#{@tenant_id}:init"
      Process.setsid

      initrc_pid = Process.fork {
        $0 = "ruby container-#{@tenant_id}:init-runner"
        Process.setsid
        inst = create_instance
        inst.run 
      }
      logger.debug "Init waiting for init-runner to finish..."
      Process.waitpid(initrc_pid)
    }

    logger.debug "Waiting for unsharing by child..."
    sleep 1
    wait_for_child  # once child creates a new network namespace, move child side of veth to the child network namespace

    logger.debug "Moving link to init (with pid: #{@init_pid}) with below command ..."
    logger.debug "ip link set #{@link_cont_name} netns #{@init_pid}"

    `ip link set #{@link_cont_name} netns #{@init_pid}`
    write_pid
 
  end

  def wait_for_child

    logger.debug "CONTINST: Waiting for child unshare ..."
    pipe = open(@in_pipe, "r")
    l = pipe.gets
    pipe.close
    logger.debug "In Line received: #{l}"
  end

  def child_ready
    output = open(@in_pipe, "w+")
    output.puts "GO FOR IT!"
    output.flush
    output.close
  end

  def write_pid
    output = open(@pid_file, "w")
    output.puts(@init_pid)
    output.flush
    output.close
  end

  def start
    output = open(@pipe, "w+")
    output.puts "GO FOR IT!"
    output.flush
    output.close
  end

  def shutdown
    #send("SIGTERM")
    #sleep 5
    output = open(@pipe, "w+")
    output.puts "shutdown"
    output.flush
    output.close
    FileUtils.rm_f(@pid_file)
  end

  def send(cmd)
    logger.debug "opening socket to host #{@container_ip}:#{@command_port} .."
    client = TCPSocket.open(@container_ip, @command_port)
    logger.debug "sending command..."
    client.send(cmd, 0)
    logger.debug "waiting for response ..."
    answer = client.gets(nil)
    logger.debug answer
    client.close
  end

  def kill_init
    pid = init_pid
    `kill -9 #{pid}`
  end

end

if ARGV.length != 2
  puts "Missing argument: usage ruby contmgr.rb tenant_id cmd"
  exit
end

tenant_id = ARGV[0]
cmd = ARGV[1]

puts "Tenant: <#{tenant_id}> Command: <#{cmd}>, my pid = #{Process.pid}"

cfg = load_conf(Config.instance['base'], tenant_id)

container1 = ContainerManager.new do |c|
  c.host_ip = cfg['host_ip']
  c.container_ip = cfg['container_ip']
  c.tenant_id = tenant_id
  c.base = cfg['base']
  c.command_port = cfg['command_port'].to_i
end

if cmd == "start"
  container1.init
  sleep 3
  container1.start
elsif cmd == "start-http"
  container1.send("SHTTPD")
elsif cmd == "stop-http"
  container1.send("THTTPD")
elsif cmd == "shutdown"
  container1.shutdown
elsif cmd == "kill"
  container1.kill_init
else
  container1.send(cmd)
end
