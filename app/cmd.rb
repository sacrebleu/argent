require "optparse"

Options = Struct.new(:name, :asg_name, :region, :lb_timeout,
                     :in_service_timeout, :force, :set)

class Cmd
  def self.parse_commandline
    parse(arguments)
  end

  def self.parse(options)
    args = Options.new("argent", nil, nil, 60, 60, false, false)

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: argent.rb [options]"

      opts.on("-aNAME", "--asg-name=", "Specify the autoscaling group name to upgrade") do |s|
        args.asg_name = s
      end

      opts.on("-rREGION", "--region=", "Specify the region in which to perform the autoscaling group upgrade") do |s|
        args.region = s
      end

      opts.on_tail("-h", "Prints these usage instructions");
    end

    if args.asg_name.present? && args.region.present?
      args.set = true
    end

    opt_parser.parse!(options)
    return args
  end

  def self.abort(opt_parser)
    puts opt_parser
  end

  def self.arguments
    ARGV
  end
end
