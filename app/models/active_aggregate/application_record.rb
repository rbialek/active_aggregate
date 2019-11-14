module ActiveAggregate
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.recent(n = 10)
      order("id DESC").limit(n)
    end

  end
end
