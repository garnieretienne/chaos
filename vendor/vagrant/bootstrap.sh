#!/usr/bin/env bash

SYSOP_USER="vagrant"
SYSOP_HOME="/home/${SYSOP_USER}"
RBENV_GIT="git://github.com/sstephenson/rbenv.git"
RUBY_BUILD_GIT="https://github.com/sstephenson/ruby-build.git"
SHARED_DIR="/vagrant"
DEBIAN_HOST_FQDN="debian.chaos.local"
DEBIAN_HOST_IP="192.168.60.2"
RUBY_PACKAGE_URL="https://dl.dropboxusercontent.com/u/15270883/ruby-2.0.0-x86_64.tgz"

echo ">>  Install pre-requistes"

# echo "    Update the system..."
# apt-get update &> /tmp/bootstrap
# apt-get upgrade --yes &> /tmp/bootstrap

echo "    Install 'wget' and 'git'..."
apt-get update &> /tmp/bootstrap
apt-get install -q -y wget git &> /tmp/bootstrap
# apt-get install -q -y build-essential &> /tmp/bootstrap

echo ">>  Configure servers"

echo "    Adding debian server (debian.chaos.local) to the hosts list..."
echo "${DEBIAN_HOST_IP} ${DEBIAN_HOST_FQDN}" >> /etc/hosts

echo ">>  Install ruby stack for the '${SYSOP_USER}' user"

echo "    Installing rbenv ..."
rm -rf $SYSOP_HOME/.rbenv
git clone $RBENV_GIT $SYSOP_HOME/.rbenv &> /tmp/bootstrap
# git clone $RUBY_BUILD_GIT $SYSOP_HOME/.rbenv/plugins/ruby-build &> /tmp/bootstrap
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> $SYSOP_HOME/.profile
echo 'eval "$(rbenv init -)"' >> $SYSOP_HOME/.profile
mkdir -p $SYSOP_HOME/.rbenv/versions
chown -R $SYSOP_USER:$SYSOP_USER $SYSOP_HOME/.rbenv

echo "    Installing ruby-2.0.0 ..."
sudo -u $SYSOP_USER -H -i << EOF 
cd $SYSOP_HOME/.rbenv/versions
wget -q https://dl.dropboxusercontent.com/u/15270883/ruby-2.0.0-x86_64.tgz
tar xzf ruby-2.0.0-x86_64.tgz && rm ruby-2.0.0-x86_64.tgz
# CONFIGURE_OPTS="--enable-shared --enable-load-relative" rbenv install 2.0.0-p0
rbenv global 2.0.0-p0
rbenv rehash
gem install bundler | sed -u 's/^/    /'
rbenv rehash
EOF

echo ">>  Configure Chaos"

echo "    Installing Chaos dependencies..."
sudo -u $SYSOP_USER -H -i << EOF 
if [[ -f $SHARED_DIR/Gemfile ]]; then
  cd $SHARED_DIR
  bundle install | sed -u 's/^/    /'
fi
EOF

echo "    Writing the 'chaos' command alias..."
echo "alias chaos='BUNDLE_GEMFILE=${SYSOP_HOME}/chaos/Gemfile bundle exec chaos'" >> $SYSOP_HOME/.profile

echo ">> Configure user account"

echo "    Generate ssh keys for the main user..."
sudo -u $SYSOP_USER -H -i << EOF
ssh-keygen -q -t rsa -f ${SYSOP_HOME}/.ssh/id_rsa -N ""
EOF
