require "chaos"

describe "[Debian]" do

  before do
    @server = Chaos::Server.new "ssh://root:vagrant@debian.chaos.local"
    @current_user = ENV['USER']
    @current_user_home = ENV['HOME']
  end

  describe "bootstrap the server" do

    let(:bootstrap) do 
      output = StringIO.new
      old_out = $stdout
      $stdout = output
      @server.bootstrap
      $stdout = old_out
      return output.string
    end

    it "should have the correct output" do
      first_bootstrap =<<END
    Setup server hostname (debian) (done)
    Upload public key for 'vagrant' user (done)
    Install dependencies git, curl, sudo (done)
    Install Chef solo if needed (done)
END
      already_bootstrapped =<<END
    Setup server hostname (debian) (done)
    Upload public key for 'vagrant' user (done)
    Install dependencies git, curl, sudo (done)
    Install Chef solo if needed (already installed)
END
      bootstrap.should satisfy { |output| [first_bootstrap, already_bootstrapped].include?(output) }
    end

    it "should have set the correct hostname" do
      remote_hostname = nil
      @server.connect do
        remote_hostname = @server.exec!("hostname").chomp
      end
      remote_hostname.should == "debian"
    end

    it "should have set the correct fully qualified domain name" do
      remote_fqdn = nil
      @server.connect do
        remote_fqdn = @server.exec!("hostname --fqdn").chomp
      end
      remote_fqdn.should == "debian.chaos.local"
    end

    it "should have uploaded the current user's public key" do
      is_pubkey_present = false
      remote_pubkey = nil
      remote_pubkey_path = "/root/admin_key/#{@current_user}.pub"
      current_user_pubkey = `cat #{@current_user_home}/.ssh/id_rsa.pub`
      @server.connect do
        exit_status, stdout = @server.exec "ls #{remote_pubkey_path}"
        is_pubkey_present = (exit_status == 0)
        if is_pubkey_present
          remote_pubkey = @server.exec! "cat #{remote_pubkey_path}"
        end
      end
      is_pubkey_present.should be true
      remote_pubkey.should == current_user_pubkey
    end

    it "should have installed dependencies (git, curl and sudo)" do
      is_sudo_installed = is_git_installed = is_curl_installed = false
      @server.connect do
        exit_status, stdout = @server.exec "which sudo"
        is_sudo_installed = (exit_status == 0)
        exit_status, stdout = @server.exec "which curl"
        is_curl_installed = (exit_status == 0)
        exit_status, stdout = @server.exec "which git"
        is_git_installed = (exit_status == 0)
      end
      is_sudo_installed.should be true
      is_curl_installed.should be true
      is_git_installed.should be true
    end

    it "should have installed chef-solo" do
      is_chef_solo_installed = false
      @server.connect do 
        exit_status, stdout = @server.exec "which chef-solo"
        is_chef_solo_installed = (exit_status == 0)
      end
      is_chef_solo_installed.should be true
    end
  end

  describe "update the system" do

    let(:system_update) do
      output = StringIO.new
      old_out = $stdout
      $stdout = output
      @server.system_update
      $stdout = old_out
      return output.string
    end

    it "should have the correct ouput" do
      system_update.should == "    updating the system using the package manager (done)\n"
    end
  end

  describe "register server's roles (app_server, service_provider)" do

    it "should have writen the correct content in the 'chaos' role file" do
      remote_role_file_path = "#{Chaos::CHAOS_SERVER_CHEF_ROLES_DIR}/chaos"
      is_role_file_exist = false
      remote_role_file_content = nil
      roles_file_content = <<END
app_server
service_provider
END

      @server.register_server_roles ['app_server', 'service_provider']
      @server.connect do
        exit_status, stdout = @server.exec "ls #{remote_role_file_path}"
        is_role_file_exist = (exit_status == 0)
        if is_role_file_exist
          remote_role_file_content = @server.exec! "cat #{remote_role_file_path}"
        end
      end

      is_role_file_exist.should be true
      remote_role_file_content.should == roles_file_content
    end
  end

  describe "run chef to configure the service with registered roles (app_server and service_provider)" do

    let!(:run_chef) do
      output = StringIO.new
      old_out = $stdout
      $stdout = output
      @server.run_chef
      $stdout = old_out
      return output
    end

    it "should have sudo installed" do
      is_sudo_installed = false
      @server.connect do
        exit_status, stdout = @server.exec "which sudo"
        is_sudo_installed = (exit_status == 0)
      end

      is_sudo_installed.should be true
    end

    it "should have everything needed to build software" do
      binaries = ["make", "gcc"]
      @server.connect do
        binaries.each do |binary|
          exit_status, stdout = @server.exec "which #{binary}"
          exit_status.should == 0
        end
      end
    end

    it "should have ruby installed system side (in /usr/bin/ruby), used by the heroku ruby buildpack" do
      @server.connect do
        exit_status, stdout = @server.exec "ls /usr/bin/ruby"
        exit_status.should == 0
      end
    end

    it "should properly create sysop accounts" do
      user_pub_key = `cat #{@current_user_home}/.ssh/id_rsa.pub`
      do_user_exist = false
      do_user_can_connect = false
      do_user_have_sudo_rights = false

      @server.connect do
        exit_status, stdout = @server.exec "cat /etc/passwd | grep #{@current_user}"
        do_user_exist = (exit_status == 0)
        exit_status, stdout = @server.exec "grep '#{user_pub_key.chomp}' #{@current_user_home}/.ssh/authorized_keys"
        do_user_can_connect = (exit_status == 0)
        exit_status, stdout = @server.exec "groups #{@current_user} | grep sudo"
        do_user_have_sudo_rights = (exit_status == 0)
      end

      do_user_exist.should be true
      do_user_can_connect.should be true
      do_user_have_sudo_rights.should be true
    end   
  end
end