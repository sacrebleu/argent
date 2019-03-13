class Sts

  def describe_user
    Aws::STS::Client.new.get_caller_identity
  end
end