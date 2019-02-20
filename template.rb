# Create Docker files
file 'Dockerfile', <<-CODE
FROM ruby:2.6-alpine

ENV APP_DIR /srv/#{app_name}

RUN apk update && apk add build-base tzdata nodejs postgresql-dev

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
      - PGHOST=postgres
      - PGUSER=postgres
    ports:
      - '3000:3000'
    volumes:
      - '.:/srv/#{app_name}'

  postgres:
    image: 'postgres:10.3-alpine'
    restart: always
    volumes:
      - './tmp/data/postgres:/var/lib/postgresql/data'
YAML

file 'docker-compose.override.yml', <<-YAML
# Use this file to override any settings in the base Compose file.
version: '3.7'

services:
  app:
  postgres:
YAML

append_to_file '.gitignore', <<-EOF

# Ignore local Docker overrides
docker-compose.override.yml
EOF
