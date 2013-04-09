module Chaos

  class Commands

    class Server < Thor

      desc "bootstrap", "Bootstrap a server"
      method_option :ssh, aliases: "-s", desc: 'ssh url used to connect to the server', required: true

      def bootstrap
        server = Chaos::Server.new options[:ssh]

        display "Bootstrapping #{server}...", :topic
        server.bootstrap

        display "Configure services using Chef...", :topic
        server.run_chef true

        user = ENV['USER']
        display "Register git user '#{user}'...", :topic
        server.register_git_user user

        display "Done.", :topic
        display "Default passwords set for admin users by chef is their user names."
        display "Connect to the server to change it ('ssh #{user}@#{server}') before doing anything else."
      end

      desc "update", "Update a server configuration running chef"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      def update
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        display "Update server configuration using Chef...", :topic
        server.run_chef
      end
    end
  end
end