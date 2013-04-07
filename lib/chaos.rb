require "chaos/version"
require "chaos/error"
require "chaos/cli"
require "chaos/server"
require "chaos/app"
require "chaos/helpers"

def display(msg, type=:message, &block)
  msg.each_line do |line|
    case type
    when :message
      msg = "    #{line.chomp} "
    when :topic
      msg = ">>  #{line.chomp} "
    when :remote
      msg = "    $  #{line.chomp} "
    when :ask
      msg = "??  #{line.chomp} "
    when :error
      msg = "!!  #{line.chomp} "
    end

    if block
      print msg
      status = block.call
      print "(#{status || 'done'})\n"
    else
      puts msg
    end
  end
end
