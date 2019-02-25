##
# 1. Install everything

# Add gems
gem 'omniauth', '~> 1.6.1'
gem 'omniauth-auth0', '~> 2.0.0'
gem 'pundit'
gem 'rolify'
gem 'sidekiq'

gem_group :development, :test do
  gem 'pry'
  gem 'pry-rails'
end

gem_group :test do
  gem 'guard'
  gem 'guard-minitest'
  gem 'minitest-rails'
  gem 'minitest-rails-capybara'
  gem 'minitest-reporters'
end

gsub_file 'Gemfile', /# (gem 'redis')/, '\1'

##
# 2. Configure everything

# Configure application
initializer 'generators.rb', <<-RUBY
Rails.application.config.generators do |g|
  g.assets false
  g.helper false
  g.scaffold_stylesheet false
  g.test_framework :spec, fixtures: true
end
RUBY

# Configure gems

# Create Docker files
file 'Dockerfile', <<-CODE
FROM ruby:2.6-alpine

ENV APP_DIR /srv/#{app_name}

RUN apk update && apk add build-base nodejs postgresql-dev

RUN mkdir ${APP_DIR}
WORKDIR ${APP_DIR}

COPY Gemfile* ./
RUN bundle install --binstubs --system -j4

COPY . .

LABEL maintainer="Andrew Porter <partydrone@icloud.com>"

CMD [ "puma", "-C", "config/puma.rb" ]
CODE

file '.dockerignore', <<-EOF
.git*
tmp/
.dockerignore
docker-compose.yml
docker-compose.override.yml
Dockerfile
README.md
EOF

file 'docker-compose.yml', <<-YAML
version: '3.7'

services:
  app:
    build: .
    depends_on:
      - 'postgres'
      - 'redis'
    env_file:
      - '.env'
    ports:
      - '3000:3000'
    volumes:
      - '.:/srv/#{app_name}'

  sidekiq:
    command: sidekiq -C config/sidekiq.yml.erb
    depends_on:
      - 'postgres'
      - 'redis'
    env_file:
      - '.env'
    image: #{app_name}_app:latest
    volumes:
      - '.:/srv/#{app_name}'

  cable:
    command: puma -p 28080 cable/config.ru
    depends_on:
      - 'redis'
    env_file:
      - '.env'
    image: #{app_name}_app:latest
    ports:
      - '28080:28080'
    volumes:
      - '.:/srv/#{app_name}'

  postgres:
    env_file:
      - '.env'
    image: 'postgres:10.3-alpine'
    volumes:
      - './tmp/data/postgres:/var/lib/postgresql/data'

  redis:
    command: redis-server --requirepass yourpassword
    image: 'redis:4.0-alpine'
    volumes:
      - './tmp/data/redis:/data'
YAML

file '.env', <<-CODE
# This is used by Docker Compose to set up prefix names for Docker images,
# containers, volumes and networks. This ensures that everything is named
# consistently regardless of your folder structure.
COMPOSE_PROJECT_NAME=#{app_name}

# What Rails environment are we in?
RAILS_ENV=development

# Rails log level.
#   Accepted values: debug, info, warn, error, fatal, or unknown
LOG_LEVEL=debug

# You would typically use `rails secret` to generate a secure token. It is
# critical that you keep this value private in production.
SECRET_TOKEN=asecuretokenwouldnormallygohere

# More details about these Puma variables can be found in config/puma.rb.
# Which address should the Puma app server bind to?
BIND_ON=0.0.0.0:3000

# Puma supports multiple threads but in development mode you'll want to use 1
# thread to ensure that you can properly debug your application.
RAILS_MAX_THREADS=1

# Puma supports multiple workers but you should stick to 1 worker in dev mode.
WEB_CONCURRENCY=1

# Requests that exceed 5 seconds will be terminated and dumped to a stacktrace.
# Feel free to modify this value to fit the needs of your project, but if you
# have any request that takes more than 5 seconds you probably need to re-think
# what you are doing 99.99% of the time.
RACK_TIMEOUT_SERVICE_TIMEOUT=5

# Required by the Postgres Docker image. This sets up the initial database when
# you first run it.
POSTGRES_USER=#{app_name}
POSTGRES_PASSWORD=yourpassword

# The database name will automatically get the Rails environment appended to it
# such as: #{app_name}_development or #{app_name}_production.
DATABASE_URL=postgresql://#{app_name}:yourpassword@postgres:5432/#{app_name}?encoding=utf8&pool=5&timeout=5000

# The full Redis URL for the Redis cache.
REDIS_CACHE_URL=redis://:yourpassword@redis:6379/0

# The namespace used by the Redis cache.
REDIS_CACHE_NAMESPACE=cache

# Action mailer (e-mail) settings.
# You will need to enable less secure apps in your Google account if you plan
# to use GMail as your e-mail SMTP server.
# You can do that here: https://www.google.com/settings/security/lesssecureapps
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=gmail.com
SMTP_USERNAME=you@gmail.com
SMTP_PASSWORD=yourpassword
SMTP_AUTH=plain
SMTP_ENABLE_STARTTLS_AUTO=true

# Not running Docker natively? Replace 'localhost' with your Docker Machine IP
# address, such as: 192.168.99.100:3000
ACTION_MAILER_HOST=localhost:3000
ACTION_MAILER_DEFAULT_FROM=you@gmail.com
ACTION_MAILER_DEFAULT_TO=you@gmail.com

# Google Analytics universal ID. You should only set this in non-development
# environments. You wouldn't want to track development mode requests in GA.
# GOOGLE_ANALYTICS_UA='xxx'

# The full Redis URL for Active Job.
ACTIVE_JOB_URL=redis://:yourpassword@redis:6379/0

# The queue prefix for all Active Jobs. The Rails environment will
# automatically be added to this value.
ACTIVE_JOB_QUEUE_PREFIX=#{app_name}:jobs

# The full Redis URL for Action Cable's back-end.
ACTION_CABLE_BACKEND_URL=redis://:yourpassword@redis:6379/0

# The full WebSocket URL for Action Cable's front-end.
# Not running Docker natively? Replace 'localhost' with your Docker Machine IP
# address, such as: ws://192.168.99.100:28080
ACTION_CABLE_FRONTEND_URL=ws://localhost:28080

# Comma separated list of RegExp origins to allow connections from.
# These values will be converted into a proper RegExp, so omit the / /.
#
# Examples:
#   http:\/\/localhost*
#   http:\/\/example.*,https:\/\/example.*
#
# Not running Docker natively? Replace 'localhost' with your Docker Machine IP
# address, such as: http:\/\/192.168.99.100*
ACTION_CABLE_ALLOWED_REQUEST_ORIGINS=http:\/\/localhost*
CODE

# Configure test suite

inside 'test' do
  file 'support/omniauth.rb', <<-RUBY
OmniAuth.config.test_mode = true

# Configure mock of supported identity provider here:
# OmniAuth.config.mock_auth[:identity] = OmniAuth::AuthHash.new({
#   provider: 'identity',
#   uid: '1234567891',
#   info: {
#     first_name: 'Saruman',
#     last_name: 'the Wise',
#     email: 'saruman@orthanc.com'
#   }
# })
RUBY

  file 'support/custom_expectations/pundit.rb', <<-'RUBY'
module Minitest::Assertions
  def assert_permit(user, record, action)
    msg = "User #{user.inspect} should be permitted to #{action} #{record}, but cannot."
    assert permit(user, record, action), msg
  end

  def refute_permit(user, record, action)
    msg = "User #{user.inspect} should NOT be permitted to #{action} #{record}, but can."
    refute permit(user, record, action), msg
  end

  def permit(user, record, action)
    cls = self.class.superclass.to_s.gsub(/Test/, "")
    cls.constantize.new(user, record).public_send("#{action.to_s}?")
  end
end

module Minitest::Expectations
  ##
  # See MiniTest::Assertions#assert_permit
  #
  #   record.must_permit user, action

  infect_an_assertion :assert_permit, :must_permit

  ##
  # See Minitest::Assertions#refute_permit
  #
  #   record.wont_permit user, action

  infect_an_assertion :refute_permit, :wont_permit
end
RUBY

  insert_into_file 'test_helper.rb', after: "require 'rails/test_help'\n" do
<<-RUBY
require 'minitest/rails'
require 'minitest/reporters'

Dir[File.expand_path('test/support/**/*.rb')].each { |file| require file }

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)
RUBY
  end

  insert_into_file 'application_system_test_case.rb', after: "require \"test_helper\"\n" do
<<-RUBY
require 'minitest/rails/capybara'
RUBY
  end
end

##
# 3. Initialize everything

after_bundle do
  run 'guard init'

  git add: '.'
end
