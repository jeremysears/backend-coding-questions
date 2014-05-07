require "bundler/gem_tasks"

desc "Regenerate proto classes"
task :protoc do
  sh %{rprotoc --out=lib/lookout/backend_coding_1 ip_event.proto}
end
