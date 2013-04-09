require 'thor'
require 'chaos/commands'
# require 'cli/app'
# require 'cli/domains'

module Chaos

  class CLI < Thor

    desc 'server', 'Manage server configuration'
    subcommand 'server', Chaos::Commands::Server

    desc 'app', 'Manage app deployment configuration'
    subcommand 'app', Chaos::Commands::App

    desc 'domains', 'Manage domains attached to applications'
    subcommand 'domains', Chaos::Commands::Domains

  end
end