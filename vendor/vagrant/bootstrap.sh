#!/usr/bin/env bash

VAGRANT_USER=vagrant
VAGRANT_HOME=/home/vagrant
RBENV_GIT=git://github.com/sstephenson/rbenv.git
RUBY_BUILD_GIT=https://github.com/sstephenson/ruby-build.git
SHARED_DIR=/vagrant

echo ">>  Install pre-requistes"

echo "    Update the system..."
apt-get update &> /tmp/bootstrap
apt-get upgrade --yes &> /tmp/bootstrap

echo "    Install 'wget' and 'git'..."
apt-get install -q -y wget git &> /tmp/bootstrap


echo ">>  Install ruby stack for the vagrant user"

echo "    Installing rbenv ..."
rm -rf $VAGRANT_HOME/.rbenv
git clone $RBENV_GIT $VAGRANT_HOME/.rbenv &> /tmp/bootstrap
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> $VAGRANT_HOME/.profile
echo 'eval "$(rbenv init -)"' >> $VAGRANT_HOME/.profile
mkdir -p $VAGRANT_HOME/.rbenv/versions
chown -R $VAGRANT_USER:$VAGRANT_USER $VAGRANT_HOME/.rbenv

echo "    Installing ruby-2.0.0 ..."
sudo -u $VAGRANT_USER -H -i << EOF 
cd $VAGRANT_HOME/.rbenv/versions
wget -q https://dl.dropboxusercontent.com/u/15270883/ruby-2.0.0-x86_64.tgz
tar xzf ruby-2.0.0-x86_64.tgz && rm ruby-2.0.0-x86_64.tgz
rbenv global 2.0.0-p0
rbenv rehash
gem install bundler | sed -u 's/^/    /'
rbenv rehash
EOF

echo ">>  Configure Chaos"

echo "    Installing Chaos dependencies..."
sudo -u $VAGRANT_USER -H -i << EOF 
if [[ -f $SHARED_DIR/Gemfile ]]; then
  cd $SHARED_DIR
  bundle install | sed -u 's/^/    /'
fi
EOF

echo "    Writing the 'chaos' command alias..."
echo "alias chaos='BUNDLE_GEMFILE=${VAGRANT_HOME}/chaos/Gemfile bundle exec ruby -I${VAGRANT_HOME}/chaos/lib ${VAGRANT_HOME}/chaos/bin/chaos'" >> $VAGRANT_HOME/.profile
