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

file 'docker-compose.yml', <<-CODE
version: '3.7'

services:
  postgres:
    image: 'postgres:10.3-alpine'
    volumes:
      - './tmp/data/postgres:/var/lib/postgresql/data'
    env_file:
      - '.env'

  redis:
    image: 'redis:4.0-alpine'
    command: redis-server --requirepass yourpassword
    volumes:
      - './tmp/data/redis:/data'

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

  CODE

  after_bundle do
    run 'guard init'
  end
