require "helpers"
require "chaos"

describe "[Debian]" do

  before(:all) do
    @server = Chaos::Server.new "ssh://root:vagrant@debian.chaos.local"
    @current_user = ENV['USER']
    @current_user_home = ENV['HOME']
  end

  around(:each) do |connected|
    @server.connect do
      connected.run
    end
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
      @server.exec!("hostname").should == "debian"
    end

    it "should have set the correct fully qualified domain name" do
      @server.exec!("hostname --fqdn").should == "debian.chaos.local"
    end

    it "should have uploaded the current user's public key" do
      remote_pubkey_path = "/root/admin_key/#{@current_user}.pub"
      current_user_pubkey = `cat #{@current_user_home}/.ssh/id_rsa.pub`.chomp
      
      is_pubkey_present = @server.exec? "ls #{remote_pubkey_path}"
      is_pubkey_present.should be true
      @server.exec!("cat #{remote_pubkey_path}").should == current_user_pubkey
    end

    it "should have installed dependencies" do
      ["git", "curl", "sudo"].each do |binary|
        @server.exec?("which #{binary}").should be true
      end
    end

    it "should have installed chef-solo" do
      @server.exec?("which chef-solo").should be true
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

    before(:all) do
      @server.register_server_roles ['app_server', 'service_provider']
    end

    it "should have writen the correct content in the 'chaos' role file" do
      remote_role_file_path = "#{Chaos::CHAOS_SERVER_CHEF_ROLES_DIR}/chaos"
      roles_file_content = <<END
app_server
service_provider
END
      is_role_file_exist = @server.exec? "ls #{remote_role_file_path}"
      is_role_file_exist.should be true
      @server.exec!("cat #{remote_role_file_path}").should == roles_file_content.chomp
    end
  end

  describe "run chef to configure the service with registered roles (app_server and service_provider)" do

    before(:all) do
      output = StringIO.new
      old_out = $stdout
      $stdout = output
      @server.run_chef
      $stdout = old_out
    end

    it "should have sudo installed" do
      @server.exec?("which sudo").should be true
    end

    it "should have everything needed to build softwares" do
      ["make", "gcc"].each do |binary|
        @server.exec?("which #{binary}").should be true
      end
    end

    it "should have ruby installed system side, used by the heroku ruby buildpack" do
        @server.exec?("ls /usr/bin/ruby").should be true
    end

    it "should properly create sysop accounts" do
      user_pub_key = `cat #{@current_user_home}/.ssh/id_rsa.pub`.chomp
      
      @server.exec?("cat /etc/passwd | grep #{@current_user}").should be true
      @server.exec?("grep '#{user_pub_key}' #{@current_user_home}/.ssh/authorized_keys").should be true
      @server.exec?("groups #{@current_user} | grep sudo").should be true
    end   
  end
end