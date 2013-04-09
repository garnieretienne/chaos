module Chaos

  class Commands    

    class App < Thor

      desc "create", "Create an application on the server"
      method_option :server, aliases: "-s", desc: 'server on which the app will be published (host[:port])', required: true
      method_option :name, aliases: "-n", desc: 'name of the app'
      def create
        server = Chaos::Server.new "ssh://#{options[:server]}"
        name = options[:name] || File.basename(Dir.pwd)
        app = Chaos::App.new name
        app.create server
      end
    end
  end
end