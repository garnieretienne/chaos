module Chaos

  class Commands 

    class Addons < Thor
      include Chaos::Helpers   

      desc "add PLAN", "Add an addon plan to the app (ex: chaos-postgresql:basic)"
      method_option :server, aliases: "-p", desc: 'server on which the app is hosted', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Add an addon plan to the app
      def add(plan)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Add addon to '#{app}' on '#{server}'...", :topic
        app.add_addon plan
      end
    end
  end
end