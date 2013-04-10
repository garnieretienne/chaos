require 'erb'

module Chaos

  module Helpers

    # Escape bash variable from given string
    def escape_bash(code)
      code.gsub(/(\$|\\)/, '$' => '\$', '\\' => '\\\\')
    end

    # Read a script template
    def script(name, binding)
      source = "#{File.dirname(__FILE__)}/../../templates/#{name}.erb"
      template = ERB.new IO.read(source), nil, '-'
      return template.result(binding)
    end

    # "display" is a reserved word in ruby (http://ruby-doc.org/core-2.0/Object.html#method-i-display)
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