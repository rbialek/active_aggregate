# -*- encoding : utf-8 -*-
#
# Aggregate records are models that can change their states by applying
# events to them
#
module ActiveAggregate

  class Base < ActiveRecord::Base
    self.abstract_class = true

    include EventHandlerUtils
    include LastEventConcern

    cattr_accessor :listen_to_domains, :last_event_ids
    after_initialize :added_to_handlers?

    def added_to_handlers?
      unless EventSubscriber.instance.included_in_handlers?(self.class)
        raise("#{self.class.name} is not included in ActiveAggregate.all_handler_names!")
      end
    end

    def self.all_handler_names
      raise("Overwrite in subclass")
    end

    # Called at boot time
    def self.load_all_children
      subscriber = EventSubscriber.instance
      puts "Loading ActiveAggregates: #{all_handler_names.join(',')}"
      all_handler_names.each do |name|
        k = name.constantize
        subscriber.add_handler(k)
      end
    end

    # apply all created events before returning self
    def self.current
      ActiveAggregate::EventHandler.current
      self
    end

    # default active aggregate primary key
    def self.uuid_key
      :uuid
    end

    # add handler based on the event class name
    # handle Event::EventName will create method:
    # def handle_Event_EventName(evt) ... end
    def self.handle(klass, &code)
      name = handler_name("handle", klass)
      define_method(name, &code) # handle_name method
    end

    def to_param
      uuid
    end

    def self.new_aggregate(uuid = nil)
      new(uuid_key => uuid)
    end

    def self.aggregate_class
      self
    end

    def self.find_by_uuid(uuid)
      id = uuid || -1
      where(uuid_key => id).first
    end

    # what domains a handler listens to
    # the first domain should be the default of the aggregate domain
    # can be overwritten in handlers example: ['tx','sales']
    def self.listen_to_domains
      raise("#{self.name} should define all event domains that this event handler listens to")
    end

    def info(extended = false)
      str = "#{self.name} applied last_event_id: #{get_last_event_id} no_aggregates: #{count}"
      # str += " [ #{aggregate_keys.join(',')} ]" if extended
      puts str
      str
    end

    attr_writer :saving_from_event_handler

    def save(*args, &block)
      if @saving_from_event_handler
        @saving_from_event_handler = false
        super
      else
        raise Exceptions::Exception('Save allowed only by applying events')
      end
    rescue => e
      return false
    end

    # @return events directly linked and applied to this aggregate
    def events
      ActiveAggregate::EventBase.where(uuid: uuid)
    end

    # @return all events applied to this aggregate using event_applications
    def applied_events(name = self.class.name)
      ActiveAggregate::EventNoSti.includes(:event_applications)
          .where('event_applications.aggregate_id'   => id,
                 'event_applications.aggregate_type' => name)
          .order("events.id DESC")

    end

  end
end