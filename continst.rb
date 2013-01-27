require 'fileutils'
require 'socket'
require './logging'

class ContainerInstance
  include Logging

  attr_accessor :host_ip, :container_ip, :tenant_id, :base, :command_port
  
  def initialize

    logger.debug "ContainerInstance, my pid = #{Process.pid}"

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

    logger.debug "LCONTINST: ifconfig #{@link_cont_name} #{@container_ip} up"
    `ifconfig #{@link_cont_name} #{@container_ip} up`
    logger.debug "LCONTINST: route..."
    `route add default gw #{@host_ip} #{@link_cont_name}`
    logger.debug "LCONTINST: lo..."
    `ifconfig lo up`

    logger.debug "LCONTINST: Launching listener..."

    @listener_pid = Process.fork {
      $0 = "ruby continst-#{@tenant_id}:listener"
      require './listener'
      listener_main(@command_port)
    }

    logger.debug 'starting sshd'
    @sshd_pid = Process.fork {
      logger.debug 'starting sshd instance'
      `/usr/sbin/sshd &`
    }

  end

  def term
    logger.debug "kill #{@listener_pid}"
    `kill #{@listener_pid}`
    logger.debug "ifconfig #{@link_cont_name} #{@container_ip} down"
    `ifconfig #{@link_cont_name} #{@container_ip} down`
    logger.debug "ip link del #{@link_cont_name}"
    `ip link del #{@link_cont_name}`
  end

  def wait_for_ok

    logger.debug "CONTINST: Waiting for ok..."
    pipe = open(@pipe, "r")
    l = pipe.gets
    pipe.close
    logger.debug "Line received: #{l}"
  end

  def wait_for_shutdown

    pipe = open(@pipe, "r")
    l = pipe.gets 
    pipe.close
    logger.debug "Got termination request: #{l}"
  end

  def run
    logger.debug "An instance of container being launched for tenant: #{@tenant_id}"
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

  logger.debug "Instance: #{tenant_id}, PID of init from inside: #{Process.ppid}"

  conf = load_conf(tenant_id)

  inst = ContainerInstance.new do |c|
    c.host_ip = conf['host_ip']
    c.container_ip = conf['container_ip']
    c.tenant_id = conf['tenant_id'].to_i
    c.base = conf['base']
    c.command_port = conf['command_port'].to_i
  end

  logger.debug "Instance for tenant #{tenant_id} configured, running it.."

  inst.run

end

if ARGV.length == 1
  inst_main(ARGV[0].to_i)
end
