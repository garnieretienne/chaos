require "chaos/helpers"
require "chaos/version"
require "chaos/error"
require "chaos/cli"
require "chaos/server"
require "chaos/app"

module Chaos

  # Temporary directory on the remote system.
  #
  # This is used by some command on the server side to temporary store files.
  TMP_DIR                     = "/tmp"

  # Deployment user.
  #
  # This user run the deployment script to build and package apps pushed by git.
  DEPLOY_USER                 = "git"

  # Deployment user home.
  DEPLOY_USER_HOME            = "/srv/#{DEPLOY_USER}"

  # Script used to start apps.
  STARTER_PATH                = "#{DEPLOY_USER_HOME}/bin/starter"

  # Directory where deploy user will look to provide ressources for addons.
  #
  # Each installed servicepacks will create an addon folder containing following scripts:
  # - detect (script to detect if the service provider can offer the asked addon plan)
  # - gateway (script to connect to the service provider and execute a command 
  #   (like 'provide' to ask for a ressource according to the addon plan name))
  ADDONS_DIR                   = "#{DEPLOY_USER_HOME}/addons"

  # User with Gitolite repo pull access.
  #
  # This user manage git repos using gitolite admin repository.
  GITOLITE_USER               = DEPLOY_USER

  # Gitolite admin repository
  GITOLITE_ADMIN_DIR          = "#{DEPLOY_USER_HOME}/gitolite-admin"

  # Directory where Gitolite store the apps git repo
  GITOLITE_APPS_REPO_DIR      = "#{DEPLOY_USER_HOME}/repositories"

  # User with nginx reload right.
  #
  # This user manage nginx routes using hermes cli tool.
  ROUTER_USER                 = DEPLOY_USER

  # Router user home.
  ROUTER_USER_HOME            = DEPLOY_USER_HOME

  # The directory where apps routes are stored (as nginx config files).
  VHOST_DIR                   = "#{ROUTER_USER_HOME}/routes"

  # Servicepacks user.
  #
  # This user allow apps server to connect to the service provider server through ssh.
  # App servers will use this account to ask for service ressources creation / deletion.
  SERVICEPACKS_USER           = "addons"

  # Servicepacks user home.
  #
  # Allowed app server's ssh keys will be stored into SERVICEPACKS_USER_HOME/.ssh/authorized_keys.
  SERVICEPACKS_USER_HOME      = "/srv/#{SERVICEPACKS_USER}"

  # Directory where servicepacks are stored.
  SERVICEPACKS_DIR            = "#{SERVICEPACKS_USER_HOME}/servicepacks"

  # Directory where apps are stored on the server.
  #
  # Each app will have it's home directory in this folder containing packages and config dirs.
  APP_DIR                     = "/srv/app"

  # Git url containing chef recipes to use with 'chef-solo'.
  #
  # This Git reposiroty contain chef recipes used to configure server (as app server and/or service provider).
  CHAOS_CHEF_REPO             = "git://github.com/garnieretienne/chaos-chef-repo.git"

  # Git branch for the chef repo.
  CHAOS_CHEF_REPO_BRANCH      = "servicepacks"

  # Directory where Chaos store its chef stack (recipes, cookbooks, roles, etc...).
  CHAOS_LIB                   = "/var/lib/chaos"

  # Directory where the chaos chef reposiroty is cloned and stored.
  CHAOS_CHEF_REPO_DIR         = "#{CHAOS_LIB}/chaos-chef-repo"

  # Role to be installed on the server.
  #
  # This directory index files writed by chaos or servicepacks 
  # containing roles names to be insered into the node.json file.
  CHAOS_SERVER_CHEF_ROLES_DIR = "#{CHAOS_LIB}/roles"

  # 'node.json' file containing roles and metadata used with chef.
  #
  # This file is called by chef and generated at runtime to attach roles configured into the 
  # CHAOS_SERVER_CHEF_ROLES_DIR to the current host.
  CHAOS_CHEF_NODE_PATH        = "#{CHAOS_LIB}/node.json"

  # Where Chaos store chef roles.
  #
  # Chef can only load roles from one directory.
  # Each setuped servicepacks will link its roles into the main chef roles directory 
  # to ensure they're available at runtime.
  CHAOS_CHEF_ROLES_DIR        = "#{CHAOS_CHEF_REPO_DIR}/roles"

end