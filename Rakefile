require 'rubygems'
require 'bundler'
require 'jettywrapper'
require 'yard'
require 'bundler/gem_tasks'

ZIP_URL = 'https://github.com/projecthydra/hydra-jetty/archive/v7.3.0.zip'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

# Get your spec rake tasks working in RSpec 2.0
require 'rspec/core/rake_task'

desc 'Default: run ci build.'
task :default => :ci

desc 'Run specs'
RSpec::Core::RakeTask.new do |t|
  if ENV['COVERAGE'] && RUBY_VERSION =~ /^1.8/
    t.rcov = true
    t.rcov_opts = %w{--exclude spec\/*,gems\/*,ruby\/* --aggregate coverage.data}
  end
end

YARD::Rake::YardocTask.new do |yt|
  yt.files   = ['lib/**/*.rb']
  yt.options = ['--readme', 'README.md']
end

desc 'Open an irb session preloaded with this library'
task :console do
  sh 'irb -rubygems -I lib -r rubydora.rb'
end

desc 'Execute Continuous Integration build'
task :ci => 'jetty:clean' do
  unless ENV['environment'] == 'test'
    exec('rake ci environment=test')
  end

  jetty_params = {
    :jetty_home   => File.expand_path(File.dirname(__FILE__) + '/jetty'),
    :quiet        => true,
    :jetty_port   => ENV['TEST_JETTY_PORT'] || 8983,
    :solr_home    => File.expand_path(File.dirname(__FILE__) + '/jetty/solr'),
    :fedora_home  => File.expand_path(File.dirname(__FILE__) + '/jetty/fedora/default'),
    :startup_wait => 90,
    :java_opts    => ['-Xmx256m', '-XX:MaxPermSize=128m']
  }

  #error = Jettywrapper.wrap(jetty_params) do
  #  nil
  #end
  #raise "test failures: #{error}" if error
  Rake::Task['coverage'].invoke
  Rake::Task['yard'].invoke
end

desc 'Execute specs against Fedora under Docker'
task 'docker:build' do
  system("docker build -t samvera/fcrepo3:latest .")
end

desc 'Execute specs against Fedora under Docker'
task 'docker:spec' do
  container = `docker run -d -p 8983:8983 samvera/fcrepo3:latest`.chomp
  puts "Waiting 10s for Fedora to start..."
  sleep 10
  Rake::Task['spec'].invoke
  killed = `docker kill #{container}`.chomp
  unless container == killed
    puts "Container (#{container}) not cleaned up successfully..."
    puts "It is likely still running and binding port 8983."
  end
end

desc 'Execute specs with coverage'
task :coverage do
  # Put spec opts in a file named .rspec in root
  ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'
  ENV['COVERAGE'] = 'true' unless ruby_engine == 'jruby'
  Rake::Task['spec'].invoke
end
