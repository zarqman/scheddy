require_relative "lib/scheddy/version"

Gem::Specification.new do |spec|
  spec.name        = "scheddy"
  spec.version     = Scheddy::VERSION
  spec.authors     = ["thomas morgan"]
  spec.email       = ["tm@iprog.com"]
  spec.homepage    = "https://github.com/zarqman/scheddy"
  spec.summary     = "Job-queue agnostic, cron-like task scheduler for Rails apps"
  spec.description = "Scheddy is a batteries-included task scheduler for Rails. It is intended as a replacement for cron and cron-like functionality (including job queue specific schedulers). It is job-queue agnostic."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency 'fugit', '~> 1.8'
  spec.add_dependency 'rails', '>= 6'
end
