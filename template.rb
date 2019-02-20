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
    environment:
      - VIRTUAL_HOST=localhost
    volumes:
      - '.:/srv/#{app_name}'

  postgres:
    env_file:
      - '.env'
    image: 'postgres:10.3-alpine'
    volumes:
      - './tmp/data/postgres:/var/lib/postgresql/data'

  proxy:
    image: 'jwilder/nginx-proxy:alpine'
    ports:
      - '80:80'
    volumes:
      - '/var/run/docker.sock:/tmp/docker.sock:ro'
YAML
