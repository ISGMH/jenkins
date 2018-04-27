#!/bin/bash --login

RUBY_VERSION=2.4.1
POSTGRES_VERSION=9.6

# install RVM + Ruby
command -v rvm >/dev/null 2>&1 || {
  gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  \curl -sSL https://get.rvm.io | bash -s stable --ruby=$RUBY_VERSION
}
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
$HOME/.rvm/bin/rvm use "$RUBY_VERSION@smart"

# install Postgres
command -v psql >/dev/null 2>&1 || {
  sudo yum -y install postgresql96-server postgresql96-contrib postgresql96-devel
  sudo "/usr/pgsql-$POSTGRES_VERSION/bin/postgresql96-setup" initdb
}
sudo systemctl start postgresql-$POSTGRES_VERSION
sudo -u postgres createuser --no-password --superuser cjt

# set "fail on error" in bash
set -e

# install gems
gem install bundler --no-rdoc --no-ri
bundle config build.pg -- --with-pg-config="/usr/pgsql-$POSTGRES_VERSION/bin/pg_config"
bundle

# lint and audit
bin/rubocop
bin/brakeman
bin/bundle-audit

# install Node
command -v node >/dev/null 2>&1 || {
  export NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/creationix/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
  ) && \. "$NVM_DIR/nvm.sh"
  nvm install node
}

# prepare environment
export RAILS_ENV=test

# prepare database
bundle exec rails db:drop db:create db:structure:load

# prepare assets
command -v identify >/dev/null 2>&1 || {
  sudo yum -y install ImageMagick
}
command -v yarn >/dev/null 2>&1 || {
  npm install -g yarn
}
bundle exec rails yarn:install
bundle exec rails assets:precompile

# run unit tests
bin/rails t

# install chromedriver
command -v chromedriver >/dev/null 2>&1 || {
  wget -N http://chromedriver.storage.googleapis.com/2.36/chromedriver_linux64.zip -P ~/
  unzip ~/chromedriver_linux64.zip -d ~/
  rm ~/chromedriver_linux64.zip
  sudo mv -f ~/chromedriver /usr/bin/
  sudo chmod +x /usr/bin/chromedriver
}

# install chrome
command -v google-chrome >/dev/null 2>&1 || {
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
  sudo yum -y install google-chrome-stable_current_x86_64.rpm
}

# run system tests
bin/rails test:system
