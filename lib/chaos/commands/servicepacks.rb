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
      end
    end
  end
end