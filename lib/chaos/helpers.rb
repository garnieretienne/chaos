require 'erb'

module Chaos

  module Helpers

    # Escape each variable from given bash code.
    # Also re-escape already escaped variable.
    #
    # @param code [String] the bash code to escape
    # @return [String] the bash code with variable escaped
    def escape_bash(code)
      code.gsub(/(\$|\\)/, '$' => '\$', '\\' => '\\\\')
    end

    # Read a script template in the given execution context.
    #
    # @param name [String] the name of the script (name.sh -> name.sh.erb)
    # @param binding [Binding] the execution context
    # @return [String] the interpreted script template (the script source)
    def template(name, binding)
      source = "#{File.dirname(__FILE__)}/../../templates/#{name}.erb"
      template = ERB.new IO.read(source), nil, '-'
      return template.result(binding)
    end

    # Print a message to the user.
    # Can use a block to display a message on the same line after the action is executed.
    #
    # @example
    #   display_ "General topic", :topic                              # => ">>  General topic "    
    #   display_ "Simple message", :message                           # => "    Simple message "
    #   display_ "command executed !", :remote                        # => "    $ command executed ! "
    #   display_ "Please enter an username: " :ask                    # => "??  Please enter an username: "
    #   display_ "Error: The remote server is not reachable", :error  # => "!!  Error: The remote server is not reachable "
    #   display_ "executing an action", :message do
    #     # ...
    #     "done !"
    #   end                                                           # => "    executing an action (done !)"
    #
    # @note "display" is a reserved word in ruby, "display_" is used instead
    #   (http://ruby-doc.org/core-2.0/Object.html#method-i-display).
    # @param msg [String] the message to display, 
    # @param type [Symbol] the message type, can be :message, :topic, :remote, :ask or :error
    def display_(msg, type=:message, &block)
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
  end
end