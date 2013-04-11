module Chaos

  class Commands

    class Domains < Thor
      include Chaos::Helpers   

      desc "add DOMAIN", "Add a domain to the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Add a domain to the app.
      #
      # @param domain [String] the domain to add
      def add(domain)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Add new domains to '#{app.name}' on '#{app.server}'...", :topic
        app.add_domain domain
      end

      desc "list", "List all domains attached to the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # List configured domain for the app.
      def list
        server = Chaos::Server.new "ssh://#{options[:server]}"
        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Domains configured for '#{app.name}' on '#{app.server}':", :topic
        app.domains
      end

      desc "remove DOMAIN", "Remove a domain from the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'

      # Remove a domain from the app configuration.
      #
      # @param domain [String] the domain to remove
      def remove(domain)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        server.ask_user_password unless server.password?

        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name, server

        display_ "Removing domains for '#{app.name}' on '#{app.server}'...", :topic
        app.remove_domain domain
      end      
    end   
  end
end