class Log

  def self.log(str, opts = {})
    options = { newline: true, timestamp: true}.merge!(opts)
    msg = if options[:timestamp]
      "[%s] %s" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"), str]
    else
      "%s" % str
    end

    options[:newline] ? puts(msg) : print(msg)
  end
end