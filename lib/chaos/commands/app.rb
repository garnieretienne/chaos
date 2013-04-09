module Chaos

  class Commands    

    class App < Thor

      desc "create", "Create an application on the server"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      def create
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display "Create app '#{app}' on '#{app.server}'...", :topic
        app.create

        display "Done.", :topic
        if File.basename(Dir.pwd) == app.name
          if Dir.exist?('.git') && !app.server.host.nil? && !app.git_url.nil?
            if system "git remote add #{app.server} git@#{app.server}:#{app}.git > /dev/null 2>&1"
              display "Git remote added to the current directory ('git push #{@server} master' to deploy)"
            end
          end
        end
        display "* Database: #{app.database}"
        display "* Git     : #{app.git}"
        display "* Url     : #{app.http}"
      end
    end
  end
end