require "rubygems"

require "bundler/setup"

Bundler.require(:default)

Dir[File.expand_path "app/**/*.rb"].each{|f| require_relative(f)}

options = Cmd.parse_commandline

if options.asg_name.blank?
  $stderr.puts "ALB name was not specified with -a".red
  exit(16)
end

if options.region.blank?
  $stderr.puts "Region was not specified with -r".red
end

client = Ec2.new

unless  client.regions.include? options.region
  puts "Region #{options.region.red} is not in the list of regions supported by the current aws-sdk gem"
  exit(17)
end

ENV['aws_region'] = options.region

# Check STS to ensure we are who we think we are
#
user = Sts.new.describe_user
Log.log "Issuing commands as #{user[:arn].yellow} on account #{user[:account].yellow}"
Log.log "Connecting to region #{options.region.light_blue}"

rollout = StaggeredRollout.new(options.asg_name)

# pp rollout.starting_instances

rollout.exec
