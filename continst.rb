require 'fileutils'
require 'socket'

class ContainerInstance

  attr_accessor :host_ip, :container_ip, :tenant_id, :base, :command_port
  
  def initialize

    puts "ContainerInstance, my pid = #{Process.pid}"

    @base = "/home/sai/platform/tenants"
    @command_port = 5555

    yield self if block_given?
    @tenant_home = "#{@base}/#{@tenant_id}"
    @pipe="#{@tenant_home}/comm_pipe.fifo"
    @link_host_name="v0-tenant-#{@tenant_id}"
    @link_cont_name="v1-tenant-#{@tenant_id}"
  end

  def runcmd(cmd)
    pid = Process.fork {
      $0 = "ruby continst-#{@tenant_id}:runcmd:#{cmd}"
      Process.setsid
      STDIN.reopen '/dev/null'
      STDOUT.reopen '/dev/null', 'a'
      STDERR.reopen STDOUT
      `#{cmd}`
    }
    
    Process.waitpid(pid)

  end

  def init

    puts "LCONTINST: ifconfig #{@link_cont_name} #{@container_ip} up"
    `ifconfig #{@link_cont_name} #{@container_ip} up`
    puts "LCONTINST: route..."
    `route add default gw #{@host_ip} #{@link_cont_name}`
    puts "LCONTINST: lo..."
    `ifconfig lo up`

    puts "LCONTINST: Launching listener..."

    @listener_pid = Process.fork {
      $0 = "ruby continst-#{@tenant_id}:listener"
      require './listener'
      listener_main(@command_port)
    }

    puts 'starting sshd'
    @sshd_pid = Process.fork {
      puts 'starting sshd instance'
      `/usr/sbin/sshd &`
    }

  end

  def term
    puts "kill #{@listener_pid}"
    `kill #{@listener_pid}`
    puts "ifconfig #{@link_cont_name} #{@container_ip} down"
    `ifconfig #{@link_cont_name} #{@container_ip} down`
    puts "ip link del #{@link_cont_name}"
    `ip link del #{@link_cont_name}`
  end

  def wait_for_ok

    puts "CONTINST: Waiting for ok..."
    pipe = open(@pipe, "r")
    l = pipe.gets
    pipe.close
    puts "Line received: #{l}"
  end

  def wait_for_shutdown

    pipe = open(@pipe, "r")
    l = pipe.gets 
    pipe.close
    puts "Got termination request: #{l}"
  end

  def run
    puts "An instance of container being launched for tenant: #{@tenant_id}"
    wait_for_ok
    init
    wait_for_shutdown
    term
  end

end

def load_conf(tenant_id)
  return Hash[*File.read("/home/sai/platform/tenants/#{tenant_id}/etc/container/container.conf").split(/[= \n]+/)]
end

def inst_main(tenant_id)

  puts "Instance: #{tenant_id}, PID of init from inside: #{Process.ppid}"

  conf = load_conf(tenant_id)

  inst = ContainerInstance.new do |c|
    c.host_ip = conf['host_ip']
    c.container_ip = conf['container_ip']
    c.tenant_id = conf['tenant_id'].to_i
    c.base = conf['base']
    c.command_port = conf['command_port'].to_i
  end

  puts "Instance for tenant #{tenant_id} configured, running it.."

  inst.run

end

if ARGV.length == 1
  inst_main(ARGV[0].to_i)
end
