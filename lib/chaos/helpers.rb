require 'erb'

module Chaos

  module Helpers

    # Rebuild an env config file.
    # Set and unset vars from an env file.
    #
    # @example
    #   rebuild_env_file @server, "/app/env_file", unset: [ 'PATH', 'APP_ENV' ], set: [ 'PATH=/new/path', 'APP_ENV=production' ], as: 'appname'
    #
    # @param server [Chaos::Server] the server hosting the env file
    # @param env_file [String] the path to the environment file to update
    # @param config [Hash] the vars to set and unset
    # @option config [Array<String>] :unset var names to delete from the env file
    # @option config [Array<String>] :set var names to add to the env file
    # @option config [String] :as the owner of the file
    # @option config [String] :sudo run the command as sudo
    def rebuild_env_file(server, env_file, config={})
      config[:unset] ||= []
      config[:set] ||= []
      config[:unset].each do |setting|
        server.exec! "sed -n '/^#{setting}=.*$/!p' #{env_file} > #{TMP_DIR}/env_#{@name} && mv #{TMP_DIR}/env_#{@name} #{env_file}", sudo: config[:sudo], as: config[:as], error_msg: "Cannot write the environment config file"
      end
      config[:set].each do |var|
        server.exec! "echo '#{var.chomp}' >> #{env_file}", sudo: config[:sudo], as: config[:as], error_msg: "Cannot write the environment config file"
      end
    end

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
          print "(#{(status) ? status.chomp : 'done'})\n"
        else
          puts msg
        end
      end
    end
  end
end