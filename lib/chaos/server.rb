require 'net/ssh'
require 'net/scp'
require 'uri'
require 'io/console'

module Chaos

  class Server
    TMP_DIR = "/tmp"
    GITOLITE_ADMIN_DIR = "/srv/git/gitolite-admin"
    CHAOS_CHEF_REPO = "git://github.com/garnieretienne/chaos-chef-repo.git"

    attr_reader :host, :port, :user

    def initialize(ssh_uri)
      uri = URI(ssh_uri)
      @host = uri.host
      @port = uri.port || 22
      @user = uri.user || ENV['USER']
      @password = uri.password
    end

    def to_s
      @host
    end

    def password?
      (@password)
    end

    def ask_user_password
      begin
        system "stty -echo"
        display "Enter password for '#{@user}' on '#{@host}': ", :ask do
          @password = STDIN.gets.chomp
          '********'
        end
      ensure
        system "stty echo"
      end
    end

    def connect
      options = { port: @port }
      if @password then
        options[:password] = @password
      else
        options[:keys] = ["#{ENV['HOME']}/.ssh/id_rsa"]
      end
      Net::SSH.start @host, @user, options do |ssh|
        @ssh = ssh
        yield ssh
        @ssh = nil
      end
    end

    def send_file(src, dst)
      uploaded = false
      Net::SCP.start(@host, @user, password: @password) do |scp|
        scp.upload! src, dst do |ch, name, sent, total|
          uploaded = true if sent == total
        end
      end
      return uploaded
    end

    def bootstrap
      fqdn = @host
      hostname = fqdn.split(/^(\w*)\.*./)[1]
      user = ENV['USER']
      home = ENV['HOME']

      display "Bootstrapping #{fqdn}...", :topic

      connect do
        
        # Update hostname on server
        display "Setup server hostname (#{hostname})" do
          script! Chaos::Helpers.script("hostname.sh", binding), error_msg: "Host name or fully qualified domain name cannot be correctly configured"
        end

        # Upload public key for current user
        display "Upload public key for '#{user}' user" do
          raise Chaos::Error, "No public key available for the current user ('#{home}/.ssh/id_rsa.pub' do not exist)" unless File.exist? "#{home}/.ssh/id_rsa.pub"
          exec! "mkdir -p /root/admin_key", error_msg: "Cannot create the admin public key folder (/root/admin_key)"
          key_sent = send_file "#{home}/.ssh/id_rsa.pub", "/root/admin_key/#{user}.pub"
          raise Chaos::Error, "Cannot upload the admin key ('#{home}/.ssh/id_rsa.pub' => '/root/admin_key/#{user}.pub')" unless key_sent
        end

        # Install dependencies
        dependencies = ['git', 'curl', 'sudo']
        display "Install dependencies #{dependencies.join(', ')}" do
          exec! "apt-get update", error_msg: "Cannot update the package management repos"
          exec! "apt-get install --assume-yes #{dependencies.join(' ')}", error_msg: "Cannot install dependencies (#{dependencies.join(' ')})"
        end

        # Install chef-solo
        display "Install Chef solo if needed" do
          exit_status, stdout = exec "which chef-solo"
          if exit_status == 0
            'already installed'
          else
            exec! "curl -L https://www.opscode.com/chef/install.sh | sudo bash", error_msg: 'Cannot install chef'
            'done'
          end
        end
      end
    end

    # Display chef output (topic and error only)
    # root must be true if no sudo is needed
    def run_chef(root=false)
      display "Configure services using Chef...", :topic
      connect do
        stdout, stderr = "", ""
        script Chaos::Helpers.script("chef.sh", binding), sudo: !root do |ch, stream, data, script_path|

          data.each_line do |line|
            display line if line =~ /^(\s\s\*.*|\w.*)/
            case stream
            when :stdout
              stdout << data
            when :stderr
              stderr << data
            end
          end

          ch.on_request("exit-status") do |ch, data|
            exit_status = data.read_long
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), "Chef encountered an error" if exit_status != 0
          end
        end
      end
    end

    def register_git_user(user)

      display "Register git user '#{user}'...", :topic
      display "Import user key into gitolite" do
        connect do
          script! Chaos::Helpers.script("register_git_user.sh", binding), error_msg: "Cannot register '#{user}' private key into gitolite admin repo"
        end
      end
    end

    def exec(cmd, options={}, &block)
      raise Chaos::Error, "No active connection to the server" if !@ssh
      
      stdout, stderr, exit_status = "", "", nil

      # Ask for user password if not set and modify the command
      if options[:sudo] || options[:as]
        ask_user_password if !@password
        cmd = "sudo #{"-u #{options[:as]} -H -i " if options[:as]}-S bash << EOS\n#{@password}\n#{cmd}\nEOS"
      end

      @ssh.open_channel do |channel|       
        channel.exec(cmd) do |ch, success|
          raise Chaos::Error, "Couldn't execute command '#{cmd}' on the remote host" unless success

          channel.on_data do |ch, data|
            block.call(ch, :stdout, data) if block
            stdout << data
          end

          channel.on_extended_data do |ch, type, data|
            block.call(ch, :stderr, data) if block
            stderr << data
          end

          channel.on_request("exit-status") do |ch, data|
            exit_status = data.read_long
          end
        end
      end

      @ssh.loop
      return exit_status, stdout, stderr, cmd
    end

    def exec!(cmd, options={})
      exit_status, stdout, stderr, cmd = exec(cmd, options)
      error_msg = options[:error_msg] || "The following command exited with an error"
      raise Chaos::RemoteError.new(stdout, stderr, exit_status, cmd), error_msg if exit_status != 0
      return stdout
    end

    # Script: upload a script and run it
    # options: sudo: true, args: '-s'
    def script(source, options={}, &block)

      remote_file = "#{TMP_DIR}/#{Time.new.to_i}"
      exec! "cat << EOS > #{remote_file} && chmod +x #{remote_file} \n#{Chaos::Helpers.escape_bash(source)}\nEOS\n", error_msg: "Couldn't write script on the remote file (#{remote_file})"

      stdout, stderr, exit_status = "", "", nil

      if block
        exec remote_file, sudo: options[:sudo], as: options[:as] do |ch, stream, data|
          block.call(ch, stream, data, remote_file)
        end
      else
        exit_status, stdout, stderr = exec remote_file, sudo: options[:sudo], as: options[:as]
      end

      return exit_status, stdout, stderr, remote_file
    end

    def script!(source, options={})
      exit_status, stdout, stderr, script_path = script(source, options)
      error_msg = options[:error_msg] || "The following script exited with an error"
      raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), error_msg if exit_status != 0
      return stdout
    end

    # Execute a psql command with root access
    def psql(cmd)
      exec "psql --command \"#{cmd}\"", as: 'postgres'
    end

    def psql!(cmd, options)
      options[:as] = 'postgres'
      exec! "psql --command \"#{cmd}\"", options
    end
  end
end