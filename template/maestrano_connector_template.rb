# Ensures a compatible version of Rails is used
RAILS_SUPPORTED = ['>= 4.2', '< 5.0']

def apply_template!

  check_compatible_rails_version
  ensure_valid_options

  #
  # Rebuild the Gemfile from scratch
  #
  template 'files/Gemfile.tt', 'Gemfile', force: true

  remove_file '.gitignore'
  copy_file 'files/gitignore', '.gitignore'
  copy_file 'files/rubocop.yml', '.rubocop.yml'

  #
  # Cleanup
  #
  after_bundle do
    remove_dir 'app/mailers'
    remove_dir 'test'
    remove_file 'app/views/layouts/application.html.erb'
    remove_file 'app/assets/stylesheets/application.css'
    remove_file 'config/routes.rb'
    copy_file 'files/spec_helper.rb', 'spec/spec_helper.rb'
    copy_file 'files/routes.rb', 'config/routes.rb'

    # Procfile and uat
    copy_file 'files/Procfile', 'Procfile'
    run 'cp config/environments/production.rb config/environments/uat.rb'
    remove_file 'config/database.yml'
    copy_file 'files/database.yml', 'config/database.yml'
    run 'echo \'uat:
    secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>\' >> config/secrets.yml'

    # Sidekiq
    copy_file 'files/sidekiq.yml', 'config/sidekiq.yml'
    copy_file 'files/sidekiq.rb', 'config/initializers/sidekiq.rb'

    # Settings
    run 'bundle exec rails g config:install'
    remove_dir 'config/settings'
    remove_file 'config/settings.yml'
    run 'mkdir config/settings'
    %w(development production test uat).each do |file|
      copy_file "settings/#{file}.yml", "config/settings/#{file}.yml", force: true
    end
    copy_file 'settings/settings.yml', 'config/settings.yml'

    copy_file 'files/application-sample.yml', 'config/application-sample.yml'

    application do
      <<-RUBY
        config.generators do |g|
          g.test_framework :rspec, fixture: false
          g.view_specs false
          g.helper_specs false
        end
      RUBY
    end

    run 'SKIP_CONFIGURATION=true bundle exec rails g connector:install'
    run 'bundle exec figaro install'
    run 'bundle exec rake railties:install:migrations'
    run 'SKIP_CONFIGURATION=true bundle exec rake db:migrate'

    run 'bundler binstubs puma --force'
    run 'bundler binstubs sidekiq --force'
    run 'bundler binstubs rake --force'

    remove_file 'config/initializers/maestrano.rb'
    copy_file 'files/maestrano.rb', 'config/initializers/maestrano.rb'

    # Init repo and commit
    git :init
    git add: '.'
    git commit: "-a -m 'Initial commit'"
  end
end

#
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
# Thanks @mattbrictson!
#

def current_directory
  @current_directory ||=
    if __FILE__ =~ %r{\Ahttps?://}
      tempdir = Dir.mktmpdir('maestrano-connector-rails-')
      at_exit { FileUtils.remove_entry(tempdir) }
      git clone: "--quiet https://github.com/maestrano/maestrano-connector-rails/ #{tempdir}"

      "#{tempdir}/template"
    else
      File.expand_path(File.dirname(__FILE__))
    end
end

# def current_directory
#   File.expand_path(File.dirname(__FILE__))
# end

# Add the current directory to the path Thor uses
# to look up files
def source_paths
  Array(super) + [current_directory]
end

# ==================================================

# Ensure we're using a compatible Rails version
def check_compatible_rails_version
  requirement = Gem::Requirement.new(RAILS_SUPPORTED)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_SUPPORTED}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

# Exit if the user has used invalid generator options.
def ensure_valid_options
  valid_options = {
    skip_gemfile: false,
    skip_bundle: false,
    skip_git: false
  }
  valid_options.each do |key, expected|
    next unless options.key?(key)
    actual = options[key]
    unless actual == expected
      fail Rails::Generators::Error, "Unsupported option: #{key}=#{actual}"
    end
  end
end

apply_template!
