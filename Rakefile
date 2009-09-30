task :default => :test

desc "Run all the tests"
task :test do
  Dir.glob "#{File.dirname(__FILE__)}/test/*.rb" do |file|
    require file
  end
end

desc "Generate the RDoc HTML documentation"
task :doc do
  FileUtils.rm_rf "#{File.dirname(__FILE__)}/doc/"
  system 'rdoc . --exclude="test/*.rb" --exclude="Rakefile" -N -v'
end
