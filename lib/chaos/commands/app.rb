module Chaos

  class Commands 

    class App < Thor
      include Chaos::Helpers   

      desc "create", "Create an application on the server"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Create an application environment to the remote server.
      def create
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Create app '#{app}' on '#{app.server}'...", :topic
        app.create

        display_ "Done.", :topic
        if File.basename(Dir.pwd) == app.name
          if Dir.exist?('.git') && !app.server.host.nil? && !app.git.nil?
            if system "git remote add #{app.server} git@#{app.server}:#{app}.git > /dev/null 2>&1"
              display_ "Git remote added to the current directory ('git push #{app.server} master' to deploy)"
            end
          end
        end
        display_ "* Database: #{app.database}"
        display_ "* Git     : #{app.git}"
        display_ "* Url     : #{app.http}"
      end

      desc "destroy", "Destroy an application on the server"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Destroy an application on the server.
      def destroy
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Destroy app '#{app}' on '#{app.server}'...", :topic
        app.destroy

        display_ "Done.", :topic
        if File.basename(Dir.pwd) == app.name
          if Dir.exist?('.git')
            if system "git remote rm #{app.server} > /dev/null 2>&1"
              display_ "Git remote '#{app.server}' removed"
            end
          end
        end
      end

      desc "stop", "Ask application processes to stop"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Ask application processes to stop.
      def stop
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Stop #{app}", :topic
        app.stop
      end

      desc "start", "Ask application processes to start"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Ask application processes to start.
      def start
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Start #{app}", :topic
        app.start
      end

      desc "restart", "Ask application processes to restart"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Ask application processes to restart.
      def restart
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Restart #{app}", :topic
        app.restart
      end
    end
  end
end