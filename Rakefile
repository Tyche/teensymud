require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/packagetask'

# files to distribute
PKG_FILES = FileList[
  'tmud.rb',
  'LICENSE',
  'CONTRIBUTORS', 
  'README',
  'farts.grammar',
  'Rakefile', 
  'db',
  'db/README',
#  'db/**/*',
  'test',
  'test/README',
#  'test/**/*',
  'lib/**/*',
  'cmd/**/*',
  'doc/**/*'
]

# get version from source code
if File.read('tmud.rb') =~ /Version\s+=\s+"(\d+\.\d+\.\d+)"/
  TMUDV = $1
else
  TMUDV = "0.0.0"
end

# make documentation
Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'tmp'
  rd.main = 'README'
  rd.title = "TeensyMUD #{TMUDV} Mud Server"
#  rd.template = 'kilmer'
#  rd.template = './rdoctemplate.rb'
  rd.rdoc_files.include('README', 'farts.grammar', 'tmud.rb', 'lib/*.rb', 'cmd/*.rb')
  rd.options << '-dSN -I gif' 
end

task :rdoc do
  sh 'cp -r tmp/* doc' 
  sh 'rm -rf tmp'
end

# run tests
Rake::TestTask.new do |t|
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

# package up a distribution
Rake::PackageTask.new("tmud", TMUDV) do |p|
    p.need_tar_gz = true
    p.need_zip = true
    p.package_files.include(PKG_FILES)
    p.package_files.exclude(/\.svn/)
end
  
desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(
    ["Main", ".", /^tmud.rb$/], 
    ["Library", "lib", /.*\.rb$/], 
    ["Commands", "cmd", /.*\.rb$/],
    ["Tests", "test", /.*\.rb$/]
  ).to_s
end
  
task :release do
  baseurl = "http://sourcery.dyndns.org/svn/teensymud"
  sh "cp pkg/tmud-#{TMUDV}.* ../release"
  sh "cp pkg/tmud-#{TMUDV}.* /c/ftp/pub/mud/teensymud"
  sh "svn add ../release/tmud-#{TMUDV}.*"
  sh "svn ci .. -m 'create new packages for #{TMUDV}'"
  sh "svn cp -m 'tagged release #{TMUDV}' #{baseurl}/trunk #{baseurl}/release/tmud-#{TMUDV}"
end

task :farts do
  sh "racc -o lib/farts_parser.rb lib/farts_parser.y"
end

task :release => [:package]
task :clean => [:clobber_rdoc]
task :package => [:rdoc]
task :default => [:farts, :rdoc, :test]
