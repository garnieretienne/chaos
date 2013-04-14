module Chaos

  # Manage app creation and management on server.
  class App
    include Chaos::Helpers
    attr_reader :name, :server, :home, :vhost, :database, :git, :http

    # The directory on the server where app are stored
    APP_DIR            = "/srv/app"
    
    # The directory where apps routes are stored (as nginx conf files)
    VHOST_DIR          = "/srv/git/routes"
    
    # Gitolite admin repository
    GITOLITE_ADMIN_DIR = "/srv/git/gitolite-admin"
    
    # User with Gitolite repo pull access
    GITOLITE_USER      = "git"
    
    # User with nginx reload right
    ROUTER_USER        = "git"

    # User with deployment rights
    DEPLOY_USER        = "git"

    # User with root psql access
    POSTGRESQL_USER    = "postgres"

    # Temporary directory on the system
    TMP_DIR            = "/tmp"

    # Script to start apps
    STARTER_PATH       = "/srv/git/bin/starter"


    # Define an app on a server to which future actions will be performed.
    def initialize(name, server)
      @name   = name
      @server = server
      @home   = "#{APP_DIR}/#{name}"
      @vhost  = "#{VHOST_DIR}/#{name}"
    end

    # Return the application name.
    #
    # @return [String] the app name
    def to_s
      @name
    end

    # Create the application environment on the attached server.
    # That will create a special user and home directory, declare an HTTP route, 
    # create a database and it access and finnally a git repo to deploy using git.
    def create
      @server.connect do

        display_ "Create app user and home directory" do
          exit_status, stdout = @server.exec "grep \"^#{@name}:\" /etc/passwd"
          if exit_status == 0
            'already created'
          else
            @server.script! template("create_user_and_home.sh", binding), sudo: true, error_msg: "Cannot create the user and home directory"
            @server.exec! "mkdir -p ~/cache ~/config ~/packages ~/domains", as: @name, error_msg: "Cannot create directory in the application folder"
            @server.exec! "touch ~/config/env", as: @name, error_msg: "Cannot create the env file (~/config/env)"
            @server.exec! "chown #{@name}:deploy ~/cache && chmod 775 ~/cache", as: @name, error_msg: "Cannot change owner or permissions on '~/cache' folder"
            @server.exec! "chown #{@name}:deploy ~/packages && chmod 775 ~/packages", as: @name, error_msg: "Cannot change owner or permissions on '~/packages' folder"
            @server.exec! "chown #{@name}:deploy ~/domains && chmod 775 ~/domains", as: @name, error_msg: "Cannot change owner or permissions on '~/domains' folder"
            'done'
          end
        end 

        display_ "Patch app profile to load running environment on new shell" do
          exit_status, stdout = @server.exec "cat #{APP_DIR}/#{@name}/.profile | grep 'If a package is running, load the app environment'"
          if exit_status == 0
            'already patched'
          else
            @server.script! template("patch_profile.sh", binding), sudo: true, error_msg: "Cannot patch the app profile file"
            'done'
          end
        end

        @domain_name = "#{@name}.#{@server.host}"
        display_ "Generate a domain name for the app" do
          @server.exec! "echo #{@domain_name} > ~/.domain", as: @name, error_msg: "Cannot write the domain name configuration file"
          "#{@domain_name}"
        end

        display_ "Create an HTTP route for #{@domain_name} -> #{@name}" do
          exit_status, stdout = @server.exec "ls #{VHOST_DIR}/#{@name}"
          if exit_status == 0
            'already declared'
          else
            @server.script! template("create_route.sh", binding), as: ROUTER_USER, error_msg: "Cannot write the route config file"
            'done'
          end
          @http = "http://#{@domain_name}"
          'done'
        end

        display_ "Create a database and special access for the app" do
          exit_status, stdout = @server.exec "psql -t --command \"SELECT * FROM has_database_privilege('#{@name}', '#{@name}', 'connect');\" | grep \"t\"", as: POSTGRESQL_USER
          if exit_status == 0
            stdout = @server.exec! "cat #{@home}/config/database", error_msg: "Cannot read database config file"
            @database = stdout.match(/DATABASE_URL=(\S*)/)[1]
            'already exist'
          else
            password = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join
            @database = "postgres://#{@name}:#{password}@127.0.0.1/#{@name}"
            @server.psql! "CREATE USER #{@name} WITH PASSWORD '#{password}';", error_msg: "Cannot create database user '#{@name}'"
            @server.psql! "CREATE DATABASE #{@name};", error_msg: "Cannot create database '#{@name}'"
            @server.psql! "GRANT ALL PRIVILEGES ON DATABASE #{@name} TO #{@name};", error_msg: "Cannot grant access on database '#{@name}' to user '#{@name}"
            @server.exec! "echo DATABASE_URL=#{@database} > #{@home}/config/database", as: @name, error_msg: "Cannot write database access to config file"
            'done'
          end
        end

        display_ "Create a git repository for the app" do
          @git = "git@#{@server.host}:#{@name}.git"
          exit_status, stdout = @server.exec "grep \"^repo #{@name}\" #{GITOLITE_ADMIN_DIR}/conf/gitolite.conf"
          if exit_status == 0
            'already exist'
          else
            @server.script! template("create_repo.sh", binding), as: GITOLITE_USER, error_msg: "Cannot create a repository for this app ('#{@name}')"
            'done'
          end
        end
      end
    end

    # Stop and destroy the application environment on the attached server.
    # That will stop the application if running, delete the HTTP route, delete the user andits home directory, 
    # delete the application database and its user access and finally remove the git repository.
    def destroy
      stop
      @server.connect do

        display_ "Delete HTTP route" do
          @server.exec! "hermes destroy #{@name} --vhost-dir #{VHOST_DIR}", as: ROUTER_USER, error_msg: "Cannot delete HTTP route for '#{@name}' app"
          'done'
        end

        display_ "Delete user and home directory" do
          @server.exec! "userdel -f #{@name}", sudo: true, error_msg: "Cannot delete user for '#{@name}' app"
          @server.exec! "rm -rf #{@home}", sudo: true, error_msg: "Cannot delete home directory for '#{@name}' app"
          'done'
        end

        display_ "Delete database and database access" do
          @server.psql! "DROP DATABASE #{@name};", error_msg: "Cannot delete database for '#{@name}' app"
          @server.psql! "DROP USER #{@name};", error_msg: "Cannot delete database user for '#{@name}' app"
          'done'
        end

        display_ "Delete git repository" do
          @server.script! template("rm_repo.sh", binding), as: GITOLITE_USER, error_msg: "Cannot delete the git repository for '#{@name}' app"
          'done'
        end
      end
    end

    # Stop the application processes.
    def stop
      @server.connect do
        display_ "Ask the application processes to stop" do
          pid_file = "#{@home}/packages/current/tmp/pids/starter.pid"
          exit_code, stdout = @server.exec "ls #{pid_file}"
          if exit_code == 0
            @server.exec! "kill $(cat #{pid_file})", as: @name, error_msg: "Cannot kill master pid"
            'done'
          else
            'no current build running'
          end
        end
      end
    end

    # Start the application processes.
    def start
      @server.connect do
        display_ "Ask the application processes to start" do
          pid_file = "#{@home}/packages/current/tmp/pids/starter.pid"
          current_package_dir = "#{@home}/packages/current"
          exit_code, stdout = @server.exec "ls #{current_package_dir}"
          if exit_code == 0
            exit_code, stdout = @server.exec "cat #{pid_file}"
            if exit_code != 0
              @server.exec! "cd #{current_package_dir}; HOME=#{current_package_dir} #{STARTER_PATH}", as: @name, error_msg: "Cannot start application"
              'done'
            else
              "current build already running (master pid: #{stdout.chomp})"
            end
          else
            'no current build, deploy first'
          end
        end
        update_route
      end
    end

    # Restart the application processes.
    def restart
      stop
      sleep 1
      start
    end

    # Update the HTTP route with the current port.
    # Look at the current build version deployed for port to redirect.
    # @note need to be connected first
    def update_route
      display_ "Update app route" do
        status_code, stdout = @server.exec "ls /srv/app/#{@name}/packages/current"
        if status_code == 0
          backends = []
          stdout = @server.exec! "cat /srv/app/#{@name}/packages/current/tmp/ports", error_msg: "Cannot read running application ports"
          stdout.each_line do |port|
            backends << "127.0.0.1:#{port.chomp}"
          end
          update_route_cmd = "hermes update #{@name} $(cat #{@home}/.domain) --upstream #{backends.join(' ')} --vhost-dir #{VHOST_DIR} --aliases $(domains=\"\"; for file in #{APP_DIR}/#{@name}/domains/*; do domains=\"${domains} $(basename ${file})\"; done; echo $domains)"
          @server.exec! update_route_cmd, as: ROUTER_USER, error_msg: "Cannot update app route"
          'done'
        else
          'no current build'
        end
      end
    end

    # Add a domain to the app.
    # This will write a config file for the specified domain, rewrite app route configuration and reload nginx.
    #
    # @param domain [String] the domain to add
    def add_domain(domain)
      @server.connect do 
        display_ "Adding '#{domain}'" do
          @server.exec! "touch #{@home}/domains/#{domain}", sudo: true, error_msg: "Cannot attach the domain name"
          'done'
        end
        update_route
      end
    end

    # Display the list of domains configured for the app.
    def domains
      @server.connect do
        main_domain = @server.exec! "cat #{APP_DIR}/#{@name}/.domain", error_msg: "Cannot access the primary app domain"
        display_ "- #{main_domain}"
        stdout = @server.exec! "ls #{@home}/domains", error_msg: "Cannot list the domains"
        stdout.each_line do |domain|
          display_ "- #{domain}"
        end
      end
    end

    # Remove a domain from the app configuration.
    # This will erase the domain configuration file, rewite the app route configuration and reload nginx.
    #
    # @param domain [String] the domain to remove
    def remove_domain(domain)
      @server.connect do 
        exit_status, stdout = @server.exec "ls #{APP_DIR}/#{@name}/domains/#{domain}"
        domain_exist = (exit_status == 0)
        display_ "Removing '#{domain}'" do
          if !domain_exist
            'not configured'
          else
            @server.exec! "rm -f #{@home}/domains/#{domain}", sudo: true, error_msg: "Cannot remove the domain"
            'done'
          end
        end
        update_route if domain_exist
      end
    end

    # Display config from app environment.
    # Read config from app configuration (do not include buildpack environments).
    def config
      @server.connect do
        app_env = @server.exec! "cat #{@home}/config/*", error_msg: "Cannot read app environment"
        app_env.each_line do |config|
          display_ "#{config}"
        end
      end
    end

    # Set a config var (bash format).
    # Write the config var into the app env config file.
    # Overwrite if the var name is already configured.
    #
    # @param var [String] config var to set (ex: FOO=bar)
    def set_config(var)
      raise Chaos::Error, "Config var must be in bash format (NAME=value)" if !var.match /^\w*=\w*$/
      @server.connect do
        var_name = var.split('=')[0]
        display_ "Setting #{var}" do
          rebuild_env_config unset: [var_name], set: [var]
          'done'
        end
      end
      restart
    end

    # Set a config var (bash format).
    # Write the config var into the app env config file.
    # Overwrite if the var name is already configured.
    #
    # @param name [String] the name of config var to unset
    def unset_config(name)
      @server.connect do
        display_ "Unsetting #{name}" do
          rebuild_env_config unset: [name.upcase]
          'done'
        end
      end
      restart
    end

    private
    
    # Rebuild the env config file.
    # Set and unset vars from the env file.
    #
    # @example
    #   rebuild_env_config unset: [ 'PATH', 'APP_ENV' ], set: [ 'PATH=/new/path', 'APP_ENV=production' ]
    #
    # @param config [Hash] the vars to set and unset
    # @option config [Array<String>] :unset var names to delete from the env file
    # @option config [Array<String>] :set var names to add to the env file
    def rebuild_env_config(config={})
      env_file = "#{@home}/config/env"
      config[:unset] ||= []
      config[:set] ||= []
      config[:unset].each do |setting|
        @server.exec! "sed -n '/^#{setting}=.*$/!p' #{env_file} > #{TMP_DIR}/env_#{@name} && mv #{TMP_DIR}/env_#{@name} #{env_file}", as: @name, error_msg: "Cannot write the environment config file"
      end
      config[:set].each do |var|
        @server.exec! "echo '#{var.chomp}' >> #{env_file}", as: @name, error_msg: "Cannot write the environment config file"
      end
    end
  end
end