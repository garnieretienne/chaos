module Chaos

  class Commands 

    class Config < Thor
      include Chaos::Helpers   

      desc "list", "Display the config vars for an app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # List all the env config vars for an app
      def list
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Config vars configured for '#{app}' on '#{app.server}':", :topic
        app.config
      end

      desc "set", "Set a new config var for an app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Set a new config var for an app
      #
      # @param var [String] the config var with its value (bash format)
      def set(var)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Set config for '#{app}' on '#{app.server}'...", :topic
        app.set_config var
      end

      desc "unset", "Unset a config var for an app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Unset a config var for an app
      #
      # @param name [String] the name of config var to remove
      def unset(var_name)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Unset config for '#{app}' on '#{app.server}'...", :topic
        app.unset_config var_name
      end
    end
  end
end