# Add gems
gem 'omniauth', '~> 1.6.1'
gem 'omniauth-auth0', '~> 2.0.0'
gem 'pundit'
gem 'rolify'

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

# Configure application

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

file '.dockerignore', <<-CODE
.git*
tmp/
.dockerignore
docker-compose.yml
docker-compose.override.yml
Dockerfile
README.md

CODE

file 'docker-compose.yml', <<-YAML
version: '3.7'

services:
  app:
    build: .
    depends_on:
      - 'postgres'
      - 'redis'
    volumes:
      - '.:/srv/#{app_name}'
    env_file:
      - '.env'

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

inside 'test' do
  file 'support/omniauth.rb' <<-RUBY
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

  file 'support/custom_expectations/pundit.rb' <<-RUBY
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

  insert_into_file 'test_helper.rb', after: "require 'rails/test_help'\n" do <<-RUBY

require 'minitest/rails'
require 'minitest/reporters'

Dir[File.expand_path('test/support/**/*.rb')].each { |file| require file }

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)

  RUBY
  end

  insert_into_file 'application_system_test_case.rb', after: 'require "test_helper"\n' do <<-RUBY
require 'minitest/rails/capybara'

  RUBY
  end
end

after_bundle do
  run 'guard init'

  git add: '.'
  git commit: "-a -m 'Initial commit'"
end
