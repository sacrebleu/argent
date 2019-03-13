class Ec2

  def ec2
    @ec2 ||= Aws::EC2::Client.new
  end

  def regions
    @regions = ec2.describe_regions&.regions.collect(&:region_name)
  end

end