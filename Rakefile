require 'rake/extensiontask'
require 'rubygems/package_task'

spec = Gem::Specification.new do |spec|
  spec.name = 'facter'
  spec.version = '3.8.0'

  spec.authors = 'Puppet Labs'
  spec.email = 'info@puppetlabs.com'
  spec.homepage = 'https://github.com/puppetlabs/facter'
  spec.summary = 'Facter gem wrapper'
  spec.description = "You can prove anything with facts!"

  spec.extensions = ['ext/facter/extconf.rb']
  spec.executables = []
  spec.files = Dir['lib/**/*.rb']
end

Gem::PackageTask.new(spec) {}

Rake::ExtensionTask.new('libfacter', spec) do |ext|
  ext.ext_dir = 'ext/facter'
  ext.lib_dir = 'lib/facter'

  ext.cross_compile  = true
  ext.cross_platform = ['x86-linux', 'x86_64-linux', 'x86-mingw32', 'x64-mingw32']
  #ext.cross_platform = ['x86_64-linux']
end

desc 'Build the native gem file under rake_compiler_dock'
task 'gem:native' do
  require 'rake_compiler_dock'

  RakeCompilerDock.sh [
    'sudo apt-get --quiet --quiet --yes install libcurl4-gnutls-dev',
    'bundle install --quiet',
    'rake cross native gem',
  ].join(' && ')
end

task :docker do
  require 'rake_compiler_dock'
  RakeCompilerDock.sh 'bash'
end
