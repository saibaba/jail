require 'fileutils'
require 'socket'

require './syscall'
require './continst'


def main

  puts "PID of init from inside: #{Process.ppid}"

  inst = ContainerInstance.new do |c|
    c.host_ip = "10.0.0.101"
    c.container_ip = "10.0.0.102"
    c.tenant_id = 1
    c.base = "/home/sai/platform/tenants"
    c.command_port = 5555
  end

  puts "Instance configured, running it.."

  inst.run

end

main
