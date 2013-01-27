require './syscall'

def ls

  pipe = IO.popen(["/bin/ls", "/", :err => [:child, :out]]) { |x|
    ls_result_with_error = x.read
    puts "ls out: #{ls_result_with_error}"
  }
  
  puts "Done invoking ls!"
end

class X

  def initialize
    @name = "sai"
  end

  def work
    puts "#{Process.pid} says, Hello #{@name} to container world!"
    ls
    puts "Goodbye #{@name} from container world!"
  end

end

puts "Started script ...."

s = Syscall.new

s.start_container(X.new, "work")

