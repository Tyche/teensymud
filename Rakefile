require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/packagetask'

# files to distribute
PKG_FILES = FileList[
  'tmud.rb',
  'LICENSE',
  'CONTRIBUTORS', 
  'README',
  'Rakefile', 
  'db',
  'db/README',
#  'db/**/*',
  'test',
  'test/**/*',
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
  rd.rdoc_files.include('README', 'tmud.rb')
  rd.options << '-adSN -I gif' 
end

task :rdoc do
  sh 'cp -r tmp/* doc' 
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
  
task :release do
  baseurl = "http://sourcery.dyndns.org/svn/teensymud"
  sh "cp pkg/tmud-#{TMUDV}.* ../release"
  sh "cp pkg/tmud-#{TMUDV}.* /c/ftp/pub/mud/teensymud"
  sh "svn add ../release/tmud-#{TMUDV}.*"
  sh "svn ci .. -m 'create new packages for #{TMUDV}'"
  sh "svn cp -m 'tagged release #{TMUDV}' #{baseurl}/trunk #{baseurl}/release/tmud-#{TMUDV}"
end

task :release => [:package]
task :clean => [:clobber_rdoc]
task :package => [:rdoc]
task :default => [:rdoc, :test]
