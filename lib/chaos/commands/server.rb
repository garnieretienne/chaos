module Chaos

  class Commands

    class Server < Thor

      desc "bootstrap", "Bootstrap a server"
      method_option :ssh, aliases: "-s", desc: 'ssh url used to connect to the server', required: true
      def bootstrap
        user = ENV['USER']
        server = Chaos::Server.new options[:ssh]
        server.bootstrap
        server.run_chef true
        server.register_git_user user
        display "Done.", :topic
        display "Default passwords set for admin users by chef is their user names."
        display "Connect to the server to change it ('ssh #{user}@#{server.host}') before doing anything else."
      end

      desc "update", "Update a server configuration running chef"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      def update
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.run_chef
      end
    end
  end
end