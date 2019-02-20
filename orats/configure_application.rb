# Configure application
initializer 'generators.rb', <<-RUBY
Rails.application.config.generators do |g|
  g.assets false
  g.helper false
  g.scaffold_stylesheet false
  g.test_framework :spec, fixtures: true
end
RUBY
