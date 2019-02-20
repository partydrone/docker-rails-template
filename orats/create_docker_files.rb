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
