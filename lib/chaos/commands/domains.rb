module Chaos

  class Commands

    class Domains < Thor

      desc "add DOMAIN", "Add a domain to the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'
      def add(domain)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name
        app.add_domain server, domain
      end

      desc "list", "List all domains attached to the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'
      def list
        server = Chaos::Server.new "ssh://#{options[:server]}"
        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name
        app.domains server
      end

      desc "remove DOMAIN", "Remove a domain from the app"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'
      def remove(domain)
        server = Chaos::Server.new "ssh://#{options[:server]}"
        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name
        app.remove_domain server, domain
      end      
    end   
  end
end