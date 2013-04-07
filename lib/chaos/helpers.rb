require 'erb'

module Chaos
  class Helpers

    # Read a script template
    def self.script(name, binding)
      source = "#{File.dirname(__FILE__)}/../../templates/#{name}.erb"
      template = ERB.new IO.read(source), nil, '-'
      return template.result(binding)
    end

    def self.escape_bash(code)
      code.gsub(/(\$|\\)/, '$' => '\$', '\\' => '\\\\')
    end
  end
end