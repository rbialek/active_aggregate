require 'active_support/concern'
module ActiveAggregate
  module HandlerConcern
    extend ActiveSupport::Concern

    class_methods do

      # Add handler based on the event class name
      # handle Event::EventName will create method:
      # def handle_Event_EventName(evt) ... end
      def handle(klass, &code)
        name = handler_name("handle", klass)
        define_method(name, &code) # handle_name method
      end


      # what domains a handler listens to
      # the first domain should be the default of the aggregate domain
      # can be overwritten in handlers example: ['tx','sales']
      def listen_to_domains
        raise("#{self.name} should define all event domains that this event handler listens to")
      end

    end

    included do
      after_initialize :added_to_handlers?
    end

    def added_to_handlers?
      unless EventSubscriber.instance.included_in_handlers?(self.class)
        raise("#{self.class.name} is not included in ActiveAggregate.all_handler_names!")
      end
    end

    # by default aggregates are being saved to the DB
    # return true if no save action is performed
    def persistent_aggregate?
      true
    end

  end
end