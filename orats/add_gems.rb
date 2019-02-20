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
