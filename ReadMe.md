## Argent
Version **0.0.1**

#### Overview

Argent is a small ruby utility intended to permit a staggered rollout of ec2s through an
autoscaling group without causing a service outage.  Typically, it woould be used
after the autoscaling group (ASG)'s launch configuration has been altered.

Argent works by determining the desired and max capacity of the named ASG.  It then

1. lists the instances in service in the ASG and stores this as the *source* list
2. Suspends some of the ASG's processes
3. increments max_size and desired_capacity on the ASG.
4. waits for the new instance to launch and come into service with status healthy
5. begins detaching and terminating instances from the *source* list, waiting each
time for a replacement to attach and go in service.
6. once all the *source* list instances have been detached and terminated, it will
   decrement desired_capacity and max_size to their original values
7. It will then detach and terminate one of the ASG instances at random
8. It will then resume autoscaling processes suspended in **2.** above
9. Finally, it will terminate.

This permits a rollout to happen in an ASG in a controlled manner, while maintaining the same
number of live instances during the deployment as exist during normal operations.

#### Usage

    bundle exec ruby -S argent.rb -r <region name> -a <asg-name>
    
#### Requirements

* ruby-2.5.1
* bundler

#### Installation

    git checkout git@github.com:sacrebleu/argent.git
    cd argent
    bundle install
    
    