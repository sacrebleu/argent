# client wrapper for the AWS autoscaling api
#
class Asg
  attr_reader :asg_name

  LIVING_STATES = ['Pending', 'Pending:Wait', 'Pending:Proceeed', 'InService']

  def initialize(name)
    @asg_name = name
  end

  def self.for(asg_name)
    Asg.new(asg_name)
  end


  # create an instance of the AWS autoscaling client
  def client
    @asg ||= Aws::AutoScaling::Client.new(region: ENV['aws_region'])
  end

  def ec2_client
    @ec2 ||= Aws::EC2::Client.new(region: ENV['aws_region'])
  end

  # utility method to list autoscaling groups, optionally filtered by asg name
  def self.groups(name=nil)
    params = {}
    params[:auto_scaling_group_names] = [ name ] if name
    Aws::AutoScaling::Client.new(region: ENV['aws_region']).describe_auto_scaling_groups(params)
  end

  # Return a boolean indicating whether the given instance status s is a state we need to consider when scaling
  #
  def self.must_consider?(s)
    LIVING_STATES.include?(s)
  end

  # is the status in service
  def self.in_service?(s)
    s == 'InService'
  end

  # pause event handling to prevent the ASG doing stuff in the background while we are scaling
  def pause_scaling_events
    client.suspend_processes(auto_scaling_group_name: asg_name,
                             scaling_processes:
                                 %w[ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance])
  end

  def resume_scaling_events
    client.resume_processes(auto_scaling_group_name: asg_name)
  end

  #
  #  analog to aws autoscaling describe-auto-scaling-groups <asg-name> - returns the asg struct for the matching name
  def description
    client.describe_auto_scaling_groups(auto_scaling_group_names: [asg_name])&.auto_scaling_groups.first
  end

  # scale the wrapped asg out to the desired capacity and max capacity specified
  def scale(max_size, desired_capacity)
    client.update_auto_scaling_group(auto_scaling_group_name: asg_name, max_size: max_size, desired_capacity: desired_capacity)
  end

  # waits for the wrapped asg to scale out and for its new instances to become available and report themselves InService
  def await_event(type="Scaleout", delay=120)
    des = description.desired_capacity
    result = false
    count = 0
    Log.log "Awaiting #{type}... ", newline: false
    while count < delay && !result
      s = summary
      result = (s[:size] == des && s[:in_service] && s[:healthy])
      sleep 1
      count += 1
    end
    Log.log "done", timestamp: false
    Log.log "Summary: #{summary.inspect}"
  end

  # list of all instances in this asg, filtered by an optional filter which is an array of
  # { name: <key>, value: <match> } objects
  def instances(filter = nil)
    res = description.instances
    filter&.each { |f| res = res.select { |r| r.send(f[:name]) == f[:value] } }
    res
  end

  # list of instances that are not terminating
  def in_service_instances
    instances([{name: :lifecycle_state, value: "InService"}])
  end

  # status summary of the asg
  def summary
    res = description

    {
      in_service: res.instances.all?{ |e| e[:lifecycle_state] == 'InService' },
      healthy: res.instances.all?{ |e| e[:health_status] == 'Healthy' },
      size: res.instances.select { |e| e[:lifecycle_state] == 'InService' }.length
    }
  end

  # query the status of the named instance
  def status_of(instance)
    description.instances.select{ |e| e.instance_id == instance}
  end

  # the named instance is present in the list of asg instances
  def present?(instance)
    description.instances.map(&:instance_id).include?(instance)
  end

  # terminate an instance in the autoscaling group after detatching it from the autoscaling group and
  # draining ELB connections
  def terminate(instance, decrement=false)
    Log.log "Detaching #{instance.instance_id.light_yellow} from ASG"
    client.detach_instances(
      instance_ids: [ instance.instance_id ],
      auto_scaling_group_name: asg_name,
      should_decrement_desired_capacity: false)

    # need to describe the instance status in the asg here so that we wait till connections have drained.
    count = 0
    Log.log "Awaiting connection draining... ", newline: false
    while present?(instance.instance_id) && count < 120
      sleep 1
      count += 1
    end
    Log.log "done", timestamp: false

    Log.log "Terminating #{instance.instance_id.light_red}... ", newline: false
    ec2_client.terminate_instances(instance_ids: [ instance.instance_id ])
    Log.log "done", timestamp: false
  end

end