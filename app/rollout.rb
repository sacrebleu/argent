require 'pp'

# This rollout strategy performs a staggered cycle of all live instances in the named autoscaling group.
#
# If at start there are n instances of version v, at the end there should be n instances of version v+1
#
class StaggeredRollout

  attr_reader :instances
  attr_reader :asg_settings
  attr_reader :starting_instances
  attr_reader :asg_name
  attr_reader :lb_type

  def initialize(asg_name, lb_type=:classic)

    @asg_name = asg_name
    @lb_type = lb_type

    asg = Asg.for(asg_name)

    description = asg.description

    raise "Could not locate ASG #{asg_name} in #{ENV['aws_region']}" unless description


    @asg_settings = {
      max_size: description.max_size,
      desired_capacity:  description.desired_capacity
    }

    @arn = description.auto_scaling_group_arn
    @starting_instances = asg.in_service_instances
  end

  # begin the process of a staggered rollout in this asg
  #
  # 1. increment max-capacity by 1 if asg instance count == max capacity
  # 2. increment desired-capacity by 1
  # 3. permit new instance to start
  # 4. terminate original instance
  # 5. repeat until all aold instances are gone
  # 6. terminate a new instance
  # 7. decrease desired capacity + max capacity
  # 8. exit
  #
  def exec
    t = Time.now.to_i
    asg = Asg.for(asg_name)

    Log.log "Starting with desired_capacity=#{asg_settings[:desired_capacity].to_s.light_blue}, max_size=#{asg_settings[:max_size].to_s.light_blue}"
    Log.log "Live instances: #{@starting_instances.collect(&:instance_id)}"
    Log.log "Pausing autoscaling processes on #{asg_name}"

    asg.pause_scaling_events
    # increment max size
    Log.log "Scaling to desired_capacity=#{(asg_settings[:desired_capacity] + 1).to_s.light_blue}, max_size=#{(asg_settings[:max_size] + 1).to_s.light_blue}"
    asg.scale(asg_settings[:max_size] + 1, asg_settings[:desired_capacity] + 1)


    asg.await_event

    @starting_instances.each do |instance|
      asg.terminate(instance)
      asg.await_event("Replacement")
    end

    finishing_instances = asg.in_service_instances
    Log.log "Live instances: #{finishing_instances.collect(&:instance_id)}"

    res = finishing_instances.any?{ |i| starting_instances.include?(i) }
    Log.log "Resetting ASG desired_capacity=#{asg_settings[:desired_capacity].to_s.light_blue}, max_size=#{asg_settings[:max_size].to_s.light_blue}"
    asg.scale(asg_settings[:max_size], asg_settings[:desired_capacity])

    Log.log "Replaced all instances: #{res ? "no".light_red : "yes".light_green}"
    asg.terminate(finishing_instances.sample)

    asg.in_service_instances
    Log.log "Live instances: #{asg.in_service_instances.collect(&:instance_id)}"
    Log.log "Resuming autoscaling processes following rollout."
    asg.resume_scaling_events

    delta = Time.now.to_i - t

    Log.log "Staged rollout to auto scaling group #{asg_name} completed#{res ? " with errors." : "."}"
    Log.log "Rollout completed in #{(delta/1000.0).truncate(2)}s"
  end
end