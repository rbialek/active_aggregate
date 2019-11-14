module ActiveAggregate
  class EventSubscriber
    include Singleton

    def self.global
      instance
    end

    def initialize
      @maps = {}
    end

    def info
      puts "-"*50
      puts "domain\t\t=>\tsubscribers"
      puts "-"*50
      @maps.each do |domain, listeners|
        names = listeners.collect{|kl| kl.name}.join(",")
        domain += domain.length<8 ? "\t\t" : "\t"
        puts "#{domain}=>\t#{names}"
      end
      puts "-"*50
    end

    def included_in_handlers?(klass)
      list = all_handlers
      list.include?(klass)
    end

    # remember listeners for each domain
    # tx => [SaleEventHandler, BuysEventHandler, WalletEventHandler]
    # sale => [SaleEventHandler]
    def add_handler(handler)
      domains = handler.listen_to_domains
      domains = [domains] if domains.is_a?(String)

      domains.each do |domain|
        @maps[domain] ||= []
        @maps[domain].push(handler)
        @maps[domain] = @maps[domain].uniq
      end
    end

    # @return handler assigned to domain
    def get_handlers(domain)
      @maps[domain] || raise("No handlers assigned to #{domain}")
    end

    def all_handlers
      @maps.values.flatten
    end

  end
end