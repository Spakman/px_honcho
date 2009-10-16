task :default => :test

desc "Run all the tests"
task :test do
  Dir.glob "#{File.dirname(__FILE__)}/test/*.rb" do |file|
    require file
  end
end

desc "Generate the RDoc HTML documentation"
task :doc do
  if `which hanna 2>/dev/null`.chomp.empty?
    puts "Hanna not installed, using the default RDoc template..."
    rdoc_command = "rdoc"
  else
    rdoc_command = "hanna"
  end
  FileUtils.rm_rf "#{File.dirname(__FILE__)}/doc/"
  system rdoc_command + ' . --exclude="test/*" --exclude="Rakefile" --exclude="apps" -q -N -m README'
end
