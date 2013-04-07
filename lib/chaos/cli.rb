require 'thor'

module Chaos

  class CLI < Thor

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