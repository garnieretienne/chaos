require 'net/ssh'
require 'net/scp'
require 'uri'
require 'io/console'
require 'chaos/helpers'

module Chaos

  # Everything needed to manage servers.
  class Server
    include Chaos::Helpers
    attr_reader :host, :port, :user
    attr_writer :password

    # Define a new server to take action on.
    #
    # @param ssh_uri [String] complete ssh URI to access the server, 
    #   ex: ssh://username:password@domain.tld
    def initialize(ssh_uri)
      uri = URI(ssh_uri)
      @host = uri.host
      @port = uri.port || 22
      @user = uri.user || ENV['USER']
      @password = uri.password
    end

    # Return the server host
    #
    # @return [String] the server host
    def to_s
      @host
    end

    # Tell if the user password on the server is memorized.
    #
    # @return [Boolean] is the user password already given
    def password?
      return (@password)
    end

    # Tell if the current host is configured to host applications.
    #
    # @return [Boolean] is the current host configured to host apps
    def app_server?
      connect do
        exit_status, stdout = exec "ls #{DEPLOY_USER_HOME}"
        return (exit_status == 0)
      end
    end

    # List and print available addons.
    def addons
      raise Chaos::Error, "The specified server ('#{@host}') is not an app server" unless app_server?
      connect do
        exit_status, stdout = exec "ls #{ADDONS_DIR}"
        stdout.each_line do |addon|
          desc = exec! "#{ADDONS_DIR}/#{addon.chomp}/detect --about", error_msg: "Cannor read addon description for #{addon}"
          display_ "* #{desc}"
        end
      end
    end

    # Ask the user for its password on the server.
    def ask_user_password
      begin
        system "stty -echo"
        display_ "Enter password for '#{@user}' on '#{@host}': ", :ask do
          @password = STDIN.gets.chomp
          '****************'
        end
      ensure
        system "stty echo"
      end
    end

    # Connect to the server using ssh.
    # If no password is memorized, try to connect using the user ssh key (in ~/.ssh/id_rsa).
    # During the connection, any actions using an ssh session can be executed.
    # 
    # @example
    #   server.connect do
    #     server.exec "apt-get update"
    #   end
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

    # Send a local file to the server using scp.
    #
    # @param src [String] local path to the file to send
    # @param dst [String] path where the file will be copied on the server
    # @return [Boolean] is the transfert completed
    def send_file(src, dst)
      uploaded = false
      Net::SCP.start(@host, @user, password: @password) do |scp|
        scp.upload! src, dst do |ch, name, sent, total|
          uploaded = true if sent == total
        end
      end
      return uploaded
    end

    # Registered roles will be used to generate a 'node.json' file at chef runtime
    #
    # @param roles [Array<String>] roles to configure on the host
    def register_server_roles(roles)
      connect do
        exec! "rm -f #{CHAOS_SERVER_CHEF_ROLES_DIR}/chaos"
        roles.each do |role|
          exec! "mkdir -p #{CHAOS_SERVER_CHEF_ROLES_DIR}; echo '#{role}' >> #{CHAOS_SERVER_CHEF_ROLES_DIR}/chaos", error_msg: "Cannot register this role on the server"
        end
      end
    end

    # Bootstrap a new server to be ready to lauch `chef-solo`.
    # It will configure the hostname and fully qualified domain name based on the `@host` given 
    #   (name.domain.tld => hostname: name, fqdn: name.domain.tld).
    # It will upload the current user pub key for ssh authentification.
    # It will install dependencies to install Chef on the server and also install it using omnibus installer.
    def bootstrap
      fqdn = @host
      hostname = fqdn.split(/^(\w*)\.*./)[1]
      user = ENV['USER']
      home = ENV['HOME']

      connect do
        
        # Update hostname on server
        display_ "Setup server hostname (#{hostname})" do
          script! template("set_hostname.sh", binding), error_msg: "Host name or fully qualified domain name cannot be correctly configured"
          'done'
        end

        # Upload public key for current user
        display_ "Upload public key for '#{user}' user" do
          raise Chaos::Error, "No public key available for the current user ('#{home}/.ssh/id_rsa.pub' do not exist)" unless File.exist? "#{home}/.ssh/id_rsa.pub"
          exec! "mkdir -p /root/admin_key", error_msg: "Cannot create the admin public key folder (/root/admin_key)"
          key_sent = send_file "#{home}/.ssh/id_rsa.pub", "/root/admin_key/#{user}.pub"
          raise Chaos::Error, "Cannot upload the admin key ('#{home}/.ssh/id_rsa.pub' => '/root/admin_key/#{user}.pub')" unless key_sent
          'done'
        end

        # Install dependencies
        dependencies = ['git', 'curl', 'sudo']
        display_ "Install dependencies #{dependencies.join(', ')}" do
          exec! "apt-get update", error_msg: "Cannot update the package management repos"
          exec! "apt-get install --assume-yes #{dependencies.join(' ')}", error_msg: "Cannot install dependencies (#{dependencies.join(' ')})"
          'done'
        end

        # Install chef-solo
        display_ "Install Chef solo if needed" do
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

    # Run `chef-solo` with the recipe configured into the chaos chef repository (CHAOS_CHEF_REPO).
    # The displayed output is splitted to better summarize the execution.
    #
    # @param root [Boolean] is the user running chef root nor need sudo command
    def run_chef(root=false)
      connect do
        stdout, stderr = "", ""
        script template("run_chef.sh", binding), sudo: !root do |ch, stream, data, script_path|

          data.each_line do |line|
            display_ line if line =~ /^(\s\s\*.*|\w.*)/
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

    # Register the previously uploaded user pub key (stored in /root/admin_key/username.pub) 
    # as allowed to push to apps git directories.
    #
    # @param user [String] the username to register, 
    #   'kurt' for '/root/admin_key/kurt.pub'
    def register_git_user(user)
      connect do
        display_ "Import user key into gitolite" do
          script! template("register_git_user.sh", binding), error_msg: "Cannot register '#{user}' private key into gitolite admin repo"
          'done'
        end
      end
    end

    # Setup a servicepack on the server.
    # It will clone the servicepack repository, link the servicepack chef roles into the server chef dir 
    # and run chef client with the new configuration.
    # The server will be able to manage ressources for the service it provide.
    #
    # @param name [String] the name of the service provided by the servicepack (ex: postgresql, redis)
    # @param git_url [String] the url of the public git repo hosting the buildpack
    def setup_servicepack(name, git_url)
      connect do
        display_ "Setup servicepack from '#{git_url}'" do
          script! template("setup_servicepack.sh", binding), sudo: true, error_msg: "Cannot install this buildpack"
          'done'
        end
      end
    end

    # Install a servicepack on the server.
    # After a servicepack has been installed on an app server, it will be able to provide addon plans offered 
    # by the service provider (the server on which the servicepack has been setuped).
    #
    # @param name [String] the name of the service provided by the servicepack (ex: postgresql, redis)
    # @param provider_host [String] the host on which the servicepack has been setuped 
    def install_servicepack(name, provider_host)
      pub_key=""
      connect do
        display_ "Get the deployment account public key" do
          pub_key = exec! "cat #{DEPLOY_USER_HOME}/.ssh/id_rsa.pub", as: DEPLOY_USER, error_msg: 'Cannot read public key'
          'done'
        end
      end
      
      provider = Chaos::Server.new "ssh://#{provider_host}"
      if provider_host == @host
        provider.password = @password
      else
        provider.ask_user_password
      end

      provider.connect do
        display_ "Register the public key on the service provider" do
          exit_status, stdout = provider.exec "cat #{SERVICEPACKS_USER_HOME}/.ssh/authorized_keys | grep \"#{pub_key.chomp}\"", as: SERVICEPACKS_USER
          if exit_status == 0
            'already registered'
          else
            provider.exec! "echo \"#{pub_key}\" >> #{SERVICEPACKS_USER_HOME}/.ssh/authorized_keys", as: SERVICEPACKS_USER, error_msg: "Cannot register this key"
            'done'
          end
        end
      end

      connect do
        display_ "Import addon detect files on '#{@host}'" do
          exec! "mkdir ~/addons/#{name}; scp #{SERVICEPACKS_USER}@#{provider}:/#{SERVICEPACKS_DIR}/#{name}/bin/detect #{ADDONS_DIR}/#{name}/detect", as: DEPLOY_USER
          'done'
        end
        
        display_ "Build the ssh gateway to service provider" do
          script! template("build_ssh_gateway.sh", binding), as: DEPLOY_USER, error_msg: "Cannot build the ssh gateway"
          'done'
        end
      end
    end

    # Uninstall servicepack
    #
    # @param name [String] the name of the service provided by the servicepack (ex: postgresql, redis)
    # @param provider_host [String] the host on which the servicepack has been setuped 
    def uninstall_servicepack(name, provider_host)
      pub_key=""

      connect do
        display_ "Remove addon gateway" do
         exec! "rm -r #{ADDONS_DIR}/#{name}", sudo: true, error_msg: "Cannot delete the addon dir ('#{ADDONS_DIR}/#{name}')"
          'done'
        end
        display_ "Get the deployment account public key" do
          pub_key = exec! "cat #{DEPLOY_USER_HOME}/.ssh/id_rsa.pub", as: DEPLOY_USER, error_msg: 'Cannot read public key'
          'done'
        end
      end

      provider = Chaos::Server.new "ssh://#{provider_host}"
      if provider_host == @host
        provider.password = @password
      else
        provider.ask_user_password
      end

      provider.connect do
        display_ "Unregister the public key from the service provider" do
          provider.exec! "sed -i '\##{pub_key.chomp}#d' #{SERVICEPACKS_USER_HOME}/.ssh/authorized_keys", as: SERVICEPACKS_USER, error_msg: "Cannot unregister this key"
          'done'
        end
      end
    end

    def list_servicepack_config(name)
      env_file = "#{SERVICEPACKS_DIR}/#{name}/env"
      connect do
        exit_status, stdout = exec "ls #{env_file}"
        if exit_status != 0
          display_ "No config set"
        else
          env = exec! "cat #{env_file}"
          env.each_line do |env_var|
            display_ env_var
          end
        end
      end
    end

    def set_servicepack_config(name, var)
      raise Chaos::Error, "Config var must be in bash format (NAME=value)" if !var.match /^.*=.*$/

      connect do
        var_name = var.split('=')[0]
        display_ "Setting #{var}" do
          rebuild_env_file self, "#{SERVICEPACKS_DIR}/#{name}/env", unset: [var_name], set: [var], sudo: true
          'done'
        end
      end
    end

    def unset_servicepack_config(name, var)
      connect do
        var_name = var.split('=')[0]
        display_ "Unsetting #{var_name}" do
          rebuild_env_file self, "#{SERVICEPACKS_DIR}/#{name}/env", unset: [var_name.upcase], sudo: true
          'done'
        end
      end
    end

    # Exec a command on the server (need to be connected).
    # It can also be used using block to work with live data.
    # See: Net::SSH `exec` command (http://net-ssh.github.io/net-ssh/classes/Net/SSH/Connection/Session.html#method-i-exec).
    #
    # @example Get the user name
    #   exit_status, stdout = server.exec "whoami"
    #   puts "username: #{stdout.chomp}"
    #
    # @example Print remote error (using block)
    #   server.exec "chef-solo" do |channel, stream, data|
    #     puts data if stream == :stderr
    #     channel.on_request("exit-status") do |ch, data|
    #       exit_status = data.read_long
    #       "Error !" if exit_status != 0
    #     end
    #   end
    #   
    # @param cmd [String] the command to execute
    # @param options [Hash] the options for the command executions
    # @option options [Boolean] :sudo run the command with sudo
    # @option options [String] :as run the command as the given user (use sudo)
    # @return [Array<String>] the exit status code, stdout, stderr and the executed command (useful for debugging)
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

    # Exec a command on the server (need to be connected) AND raise an error if the command failed.
    # If an error is raised, it will print the backtrace, the stdout and stderr, the command and its exit status code.
    #
    # @param cmd [String] the command to execute
    # @param options [Hash] the options for the command executions
    # @option options [Boolean] :sudo run the command with sudo
    # @option options [String] :as run the command as the given user (use sudo)
    # @option options [String] :error_message ('The following command exited with an error') the error message to print when an error is raised
    # @return [String] the standart ouput returned by the command
    def exec!(cmd, options={})
      exit_status, stdout, stderr, cmd = exec(cmd, options)
      error_msg = options[:error_msg] || "The following command exited with an error"
      raise Chaos::RemoteError.new(stdout, stderr, exit_status, cmd), error_msg if exit_status != 0
      return stdout
    end

    # Execute a script on the remote host. 
    # It write the source on a temporary file and execute it.
    # As `exec`, it can also be used using block to work with live data.
    # See {#exec}
    #
    # @param source [String] the script text to execute
    # @param options [Hash] the options for the script execution
    # @option options [Boolean] :sudo execute the script with sudo
    # @option options [String] :as execute the script as the given user (use sudo)
    # @return [Array<String>] the exit status code, stdout, stderr and the executed command (useful for debugging)
    def script(source, options={}, &block)

      remote_file = "#{TMP_DIR}/#{Time.new.to_i}"
      exec! "cat << EOS > #{remote_file} && chmod +x #{remote_file} \n#{escape_bash(source)}\nEOS\n", error_msg: "Couldn't write script on the remote file (#{remote_file})"

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

    # Execute a script on the remote host AND raise an error if the script execution failed.
    # If an error is raised, it will print the backtrace, the stdout and stderr, the script path and its exit status code.
    #
    # @param source [String] the script text to execute
    # @param options [Hash] the options for the script execution
    # @option options [Boolean] :sudo execute the script with sudo
    # @option options [String] :as execute the script as the given user (use sudo)
    # @option options [String] :error_message ('The following script exited with an error') the error message to print when an error is raised
    # @return [String] the standart ouput returned by the script
    def script!(source, options={})
      exit_status, stdout, stderr, script_path = script(source, options)
      error_msg = options[:error_msg] || "The following script exited with an error"
      raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), error_msg if exit_status != 0
      return stdout
    end

    # Execute a `psql` command with root permission.
    #
    # @param cmd [String] the psql command to execute
    # @return [Array] the exit status code, stdout, stderr and the executed command (useful for debugging)
    def psql(cmd)
      exec "psql --command \"#{cmd}\"", as: 'postgres'
    end

    # Execute a `psql` command with root permission AND raise an error if the command failed.
    # If an error is raised, it will print the backtrace, the stdout and stderr, the command and its exit status code.
    #
    # @param cmd [String] the psql command to execute
    # @param options [Hash] the options for the command executions
    # @option options [String] :error_message ('The following command exited with an error') the error message to print when an error is raised
    # @return [String] the standart ouput returned by the command
    def psql!(cmd, options)
      options[:as] = 'postgres'
      exec! "psql --command \"#{cmd}\"", options
    end
  end
end