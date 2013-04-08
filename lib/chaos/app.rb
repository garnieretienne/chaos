module Chaos

  class App
    APP_DIR            = "/srv/app"
    VHOST_DIR          = "/srv/git/routes"
    GITOLITE_ADMIN_DIR = "/srv/git/gitolite-admin"
    GITOLITE_USER      = "git"
    ROUTER_USER        = "git"
    POSTGRESQL_USER    = "postgres"

    def initialize(name)
      @name = name
      @home = "#{APP_DIR}/#{name}"
      @vhost = "#{VHOST_DIR}/#{name}"
    end

    def create(server)
      @server = server
      @server.ask_user_password unless @server.password?

      display "Create app '#{@name}' on '#{server}'...", :topic

      server.connect do |ssh|

        display "Create app user and home directory" do
          stdout, stderr, exit_status = @server.exec ssh, "grep \"^#{@name}:\" /etc/passwd"
          if exit_status ==0
            'already created'
          else
            stdout, stderr, exit_status, script_path = @server.script ssh, Chaos::Helpers.script("create_user_and_home.sh", binding), sudo: true
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), "Cannot create the user and home directory" if exit_status != 0
            stdout, stderr, exit_status, command = @server.exec ssh, "mkdir -p ~/cache ~/config ~/packages", sudo: true, as: @name
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot create directory in the application folder" if exit_status != 0
            stdout, stderr, exit_status, command = @server.exec ssh, "chown #{@name}:deploy ~/cache && chmod 775 ~/cache", sudo: true, as: @name
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot change owner or permissions on '~/cache' folder" if exit_status != 0
            stdout, stderr, exit_status, command = @server.exec ssh, "chown #{@name}:deploy ~/packages && chmod 775 ~/packages", sudo: true, as: @name  
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot change owner or permissions on '~/packages' folder" if exit_status != 0
            'done'
          end
        end 

        display "Patch app profile to load running environment on new shell" do
          stdout, stderr, exit_status = @server.exec ssh, "cat #{APP_DIR}/#{@name}/.profile | grep 'If a package is running, load the app environment'"
          if exit_status == 0
            'already patched'
          else
            stdout, stderr, exit_status, script_path = @server.script ssh, Chaos::Helpers.script("patch_profile.sh", binding), sudo: true
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), "Cannot patch the app profile file" if exit_status != 0
            'done'
          end
        end

        @domain_name = "#{@name}.#{@server.host}"
        display "Generate a domain name for the app (#{@domain_name})" do
          stdout, stderr, exit_status, command = @server.exec ssh, "echo #{@domain_name} > ~/.domain", sudo: true, as: @name
          raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot write the domain name configuration file" if exit_status != 0
        end

        # create_route ssh

        display "Create an HTTP route for #{@domain_name} -> #{@name}" do
          stdout, stderr, exit_status = @server.exec ssh, "ls #{VHOST_DIR}/#{@name}"
          if exit_status == 0
            'already declared'
          else
            stdout, stderr, exit_status, script_path = @server.script ssh, Chaos::Helpers.script("create_route.sh", binding), sudo: true, as: ROUTER_USER
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), "Cannot write the route config file" if exit_status != 0
            'done'
          end
        end

        display "Create a database and special access for the app" do
          stdout, stderr, exit_status = @server.exec ssh, "psql -t --command \"SELECT * FROM has_database_privilege('#{@name}', '#{@name}', 'connect');\" | grep \"t\"", sudo: true, as: POSTGRESQL_USER
          if exit_status == 0
            stdout, stderr, exit_status, command = @server.exec ssh, "cat #{@home}/config/database"
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot read database config file" if exit_status != 0
            @database_uri = stdout.match(/DATABASE_URL=(\S*)/)[1]
            'already exist'
          else
            password = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join
            @database_uri = "postgres://#{@name}:#{password}@127.0.0.1/#{@name}"
            stdout, stderr, exit_status, command = @server.psql ssh, "CREATE USER #{@name} WITH PASSWORD '#{password}';"
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot create database user '#{@name}'" if exit_status != 0
            stdout, stderr, exit_status, command = @server.psql ssh, "CREATE DATABASE #{@name};"
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot create database '#{@name}'" if exit_status != 0
            stdout, stderr, exit_status, command = @server.psql ssh, "GRANT ALL PRIVILEGES ON DATABASE #{@name} TO #{@name};"
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot grant access on database '#{@name}' to user '#{@name}" if exit_status != 0
            stdout, stderr, exit_status, command = @server.exec ssh, "echo DATABASE_URL=#{@database_uri} > #{@home}/config/database", sudo: true, as: @name
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, command), "Cannot write database access to config file" if exit_status != 0
            'done'
          end
        end

        display "Create a git repository for the app" do
          @git_url = "git@#{@server.host}:#{@name}.git"
          stdout, stderr, exit_status = @server.exec ssh, "grep \"^repo #{@name}\" #{GITOLITE_ADMIN_DIR}/conf/gitolite.conf"
          if exit_status == 0
            'already exist'
          else
            stdout, stderr, exit_status, script_path = @server.script ssh, Chaos::Helpers.script("create_repo.sh", binding), sudo: true, as: GITOLITE_USER
            raise Chaos::RemoteError.new(stdout, stderr, exit_status, script_path), "Cannot create a repository for this app ('#{@name}')" if exit_status != 0
            'done'
          end
        end

      end

      display "Done.", :topic
      if File.basename(Dir.pwd) == @name
        if Dir.exist?('.git') && !@server.host.nil? && !@git_url.nil?
          if system "git remote add srv1.yuweb.fr git@srv1.yuweb.fr:comit.git > /dev/null 2>&1"
            display "Git remote added to the current directory (git push #{@server.host} master to deploy)"
          end
        end
      end
      display "* Database: #{@database_uri}"
      display "* Git     : #{@git_url}"
      display "* Url     : http://#{@domain_name}"
    end
  end
end