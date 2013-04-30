module Chaos

  class Commands 

    class Addons < Thor
      include Chaos::Helpers   

      desc "add PLAN", "Add an addon plan to the app (ex: chaos-postgresql:basic)"
      method_option :server, aliases: "-s", desc: 'server on which the app is hosted', required: true
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

      desc "remove PLAN", "Remove an addon plan from the app (ex: chaos-postgresql:basic)"
      method_option :server, aliases: "-s", desc: 'server on which the app is hosted', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'      

      # Remove and addon from the app
      def remove(plan)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Remove addon from '#{app}' on '#{server}'...", :topic
        app.remove_addon plan  
      end

      desc "list", "List addons subscribed by an app"
      method_option :server, aliases: "-s", desc: 'server on which the app is hosted', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # List addons subscribed by an app
      def list
        server = Chaos::Server.new "ssh://#{options[:server]}"

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Addons subscribed by '#{app}' on '#{server}'...", :topic
        app.addons
      end      
    end
  end
end