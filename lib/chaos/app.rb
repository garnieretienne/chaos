module Chaos

  class App
    include Chaos::Helpers
    attr_reader :name, :server, :home, :vhost, :database, :git, :http

    APP_DIR            = "/srv/app"
    VHOST_DIR          = "/srv/git/routes"
    GITOLITE_ADMIN_DIR = "/srv/git/gitolite-admin"
    GITOLITE_USER      = "git"
    ROUTER_USER        = "git"
    POSTGRESQL_USER    = "postgres"

    def initialize(name, server)
      @name   = name
      @server = server
      @home   = "#{APP_DIR}/#{name}"
      @vhost  = "#{VHOST_DIR}/#{name}"
    end

    def to_s
      @name
    end

    def create
      @server.connect do

        display_ "Create app user and home directory" do
          exit_status, stdout = @server.exec "grep \"^#{@name}:\" /etc/passwd"
          if exit_status == 0
            'already created'
          else
            @server.script! script("create_user_and_home.sh", binding), sudo: true, error_msg: "Cannot create the user and home directory"
            @server.exec! "mkdir -p ~/cache ~/config ~/packages ~/domains", as: @name, error_msg: "Cannot create directory in the application folder"
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
            @server.script! script("patch_profile.sh", binding), sudo: true, error_msg: "Cannot patch the app profile file"
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
            @server.script! script("create_route.sh", binding), as: ROUTER_USER, error_msg: "Cannot write the route config file"
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
            @server.script! script("create_repo.sh", binding), as: GITOLITE_USER, error_msg: "Cannot create a repository for this app ('#{@name}')"
            'done'
          end
        end

      end
    end

    # Update the app route
    # ex: new domains
    def update_route
      display_ "Update app route" do
        backends = []
        stdout = @server.exec! "cat /srv/app/#{@name}/packages/current/tmp/ports", error_msg: "Cannot read running application ports"
        stdout.each_line do |port|
          backends << "127.0.0.1:#{port.chomp}"
        end
        update_route_cmd = "hermes update #{@name} $(cat #{@home}/.domain) --upstream #{backends.join(' ')} --vhost-dir #{VHOST_DIR} --aliases $(domains=\"\"; for file in #{APP_DIR}/#{@name}/domains/*; do domains=\"${domains} $(basename ${file})\"; done; echo $domains)"
        @server.exec! update_route_cmd, as: ROUTER_USER, error_msg: "Cannot update app route"
        'done'
      end
    end

    def add_domain(domain)
      @server.connect do 
        display_ "Adding '#{domain}'" do
          @server.exec! "touch #{APP_DIR}/#{@name}/domains/#{domain}", sudo: true, error_msg: "Cannot attach the domain name"
          'done'
        end
        update_route
      end
    end

    def domains
      @server.connect do
        main_domain = @server.exec! "cat #{APP_DIR}/#{@name}/.domain", error_msg: "Cannot access the primary app domain"
        display_ "- #{main_domain}"
        stdout = @server.exec! "ls #{APP_DIR}/#{@name}/domains", error_msg: "Cannot list the domains"
        stdout.each_line do |domain|
          display_ "- #{domain}"
        end
      end
    end

    def remove_domain(domain)
      @server.connect do 
        exit_status, stdout = @server.exec "ls #{APP_DIR}/#{@name}/domains/#{domain}"
        domain_exist = (exit_status == 0)
        display_ "Removing '#{domain}'" do
          if !domain_exist
            'not configured'
          else
            @server.exec! "rm -f #{APP_DIR}/#{@name}/domains/#{domain}", sudo: true, error_msg: "Cannot remove the domain"
            'done'
          end
        end
        update_route if domain_exist
      end
    end
  end
end