require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/packagetask'

# get version 
require 'lib/version'

# files to distribute
PKG_FILES = FileList[
  'tmud.rb', 'tclient.rb', 'dbload.rb', 'dbdump.rb', 'config.yaml',
  'LICENSE', 'CONTRIBUTORS', 'CHANGELOG', 'README', 'TML',
  'farts.grammar', 'Rakefile', 
  'db', 'db/README', 'db/testworld.yaml',
  'farts', 'farts/**/*',
  'test', 'test/**/*', 
  'logs', 'logs/README',
  'lib/**/*',
  'vendor/**/*',
  'cmd/**/*',
  'doc/**/*'
]

# make documentation
Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'tmp'
  rd.main = 'README'
  rd.title = "TeensyMUD #{Version} Mud Server"
#  rd.template = 'kilmer'
#  rd.template = './rdoctemplate.rb'
  rd.rdoc_files.include('README', 'farts.grammar', 'TML', 'tmud.rb', 'tclient.rb',
    'dbload.rb', 'dbdump.rb',  'config.yaml',
    'lib/*.rb', 'lib/net/*.rb', 'lib/farts/*.rb', 'lib/protocol/*.rb', 
    'lib/db/*.rb', 'lib/event/*.rb', 'cmd/*.rb')
  rd.options << '-dSN -I gif' 
end

task :rdoc do
  sh 'cp -r tmp/* doc' 
  sh 'rm -rf tmp'
end

# run tests
Rake::TestTask.new do |t|
  t.libs << "vendor" << "test"  # default "lib"
  #t.pattern = 'test/test*.rb'  # default 'test/test*.rb'
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
  t.options = "-c test/test_config.yaml"
end

# package up a distribution
Rake::PackageTask.new("tmud", Version) do |p|
    p.need_tar_gz = true
    p.need_zip = true
    p.package_files.include(PKG_FILES)
    p.package_files.exclude(/\.svn/)
end
  
desc "Report code statistics (KLOCs, etc) from the application"
task :stats do |t|
  require 'code_statistics'
  CodeStatistics.new(
    ["Main", ".", /^tmud.rb$|^tclient.rb$/], 
    ["Library", "lib", /.*\.rb$/], 
    ["Database", "lib/db", /.*\.rb$/], 
    ["Event", "lib/event", /.*\.rb$/], 
    ["Farts", "lib/farts", /.*\.rb$/], 
    ["Network", "lib/net", /.*\.rb$/], 
    ["Protocol", "lib/protocol", /.*\.rb$/], 
    ["Commands", "cmd", /.*\.rb$/],
    ["Tests", "test", /.*\.rb$/]
  ).to_s
end

desc "Make a code release"
task :release do
  baseurl = "http://sourcery.dyndns.org/svn/teensymud"
  sh "cp pkg/tmud-#{Version}.* ../release"
  sh "cp pkg/tmud-#{Version}.* /c/ftp/pub/mud/teensymud"
  sh "svn add ../release/tmud-#{Version}.*"
  sh "svn ci .. -m 'create new packages for #{Version}'"
  sh "svn cp -m 'tagged release #{Version}' #{baseurl}/trunk #{baseurl}/release/tmud-#{Version}"
end

desc "Rebuild the FARTS interpreter"
task :farts do
  sh "racc -o lib/farts/farts_parser.rb lib/farts/farts_parser.y"
end

task :release => [:package]
#task :clean => [:clobber_rdoc]
task :package => [:rdoc]
task :default => [:farts, :rdoc, :test]
