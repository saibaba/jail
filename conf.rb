
module Config
  def instance
    Config.instance
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.instance
    @instance ||= { "base" => "/home/sai/platform/tenants" }
  end

end

def load_conf(base, tenant_id)
  Hash[*File.read("#{base}/#{tenant_id}/etc/container/container.conf").split(/[= \n]+/)]
end
