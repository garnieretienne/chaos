module Chaos

  class Commands 

    class Servicepacks < Thor
      include Chaos::Helpers   

      desc "setup NAME GIT_URL", "Setup a service offering addons on the server"
      method_option :provider, aliases: "-p", desc: 'server on which the service provider will be installed', required: true

      # Setup a service offering addons on the server
      def setup(name, git_url)
        server = Chaos::Server.new "ssh://#{options[:provider]}"
        server.ask_user_password unless server.password?

        display_ "Setup servicepack '#{name}' on '#{server}'...", :topic
        server.setup_servicepack name, git_url

        display_ "Rebuild service configuration using chef...", :topic
        server.run_chef

        if server.app_server?
          display_ "Install servicepack '#{name}'...", :topic
          server.install_servicepack name, options[:provider]
        end
      end

      desc "install NAME", "Install a gateway to a service provider on the server"
      method_option :provider, aliases: "-p", desc: 'server which provide the service', required: true
      method_option :server, aliases: "-s", desc: 'server on which the gateway will be installed', required: true

      # Setup a service offering addons on the server
      def install(name)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        display_ "Install servicepack '#{name}' from '#{options[:provider]}' on '#{server}'...", :topic
        server.install_servicepack name, options[:provider]
      end

      desc "uninstall NAME", "Uninstall addon gateway from the server"
      method_option :provider, aliases: "-p", desc: 'server which provide the service', required: true
      method_option :server, aliases: "-s", desc: 'server on which the gateway will be uninstalled', required: true

      # Uninstall addon gateway from the server
      def uninstall(name)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        display_ "Uninstall servicepack '#{name}' from '#{options[:provider]}' on '#{server}'...", :topic
        server.uninstall_servicepack name, options[:provider]
      end

      desc "config NAME [VAR]", "Show or edit an the buildpack env file"
      method_option :provider, aliases: "-p", desc: 'server which provide the service', required: true
      method_option :delete, aliases: "-d", desc: 'delete the env variable'

      def config(name, var=nil)
        server = Chaos::Server.new "ssh://#{options[:provider]}"

        if var
          server.ask_user_password unless server.password?
          display_ "Update servicepack config for '#{name}' on '#{server}':", :topic
          if options[:delete]
            server.unset_servicepack_config name, var
          else
            server.set_servicepack_config name, var
          end
          display_ "Rebuild service configuration using chef...", :topic
          server.run_chef
        else
          display_ "Show servicepack config for '#{name}' on '#{server}':", :topic
          server.list_servicepack_config name
        end
      end
    end
  end
end