module Chaos

  class Commands

    class Server < Thor
      include Chaos::Helpers   

      desc "bootstrap SSH_URL", "Bootstrap a server"
      method_option :roles, roles: "-r", desc: 'roles to install (app_server, service_provider)', type: :array, default: [ "app_server", "service_provider" ]

      # Bootstrap a new server.
      # This will configure the remote server to be able to run chef-solo, 
      # run it to configure services with the chaos chef recipes
      # and register the current user as admin user on the server (sudo and git rights).
      def bootstrap(ssh_url)
        server = Chaos::Server.new ssh_url

        display_ "Bootstrapping #{server}...", :topic
        server.bootstrap

        display_ "Configure services using Chef...", :topic
        server.generate_chef_config options[:roles]
        server.run_chef true

        user = ENV['USER']
        display_ "Register git user '#{user}'...", :topic
        server.register_git_user user

        display_ "Done.", :topic
        display_ "Default passwords set for admin users by chef is their user names."
        display_ "Connect to the server to change it ('ssh #{user}@#{server}') before doing anything else."
      end

      # Update the server configuration.
      # This will update the server services configuration by running chef-solo with the updated chaos recipes.
      desc "update", "Update a server configuration running chef"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      def update
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        display_ "Update server configuration using Chef...", :topic
        server.run_chef
      end
    end
  end
end