def run(command)
  system(command) or raise "command failed: #{command}"
end

namespace "test" do
  desc "Run iOS unit tests"
  task :ios do |t|
    run "xcodebuild -project OAuth2.xcodeproj -scheme OAuth2-iOS -destination 'platform=iOS Simulator,name=iPhone 6s' clean test"
  end
end

task default: ["test:ios"]
