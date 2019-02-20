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