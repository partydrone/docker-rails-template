require_relative 'add_gems'
require_relative 'configure_application'
require_relative 'create_docker_files'
require_relative 'create_env_file'
require_relative 'configure_test_suite'

after_bundle do
  run 'guard init'

  git add: '.'
end
