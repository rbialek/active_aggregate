require 'active_support/concern'

module ActiveAggregate
  module EventHandlerUtils
    extend ActiveSupport::Concern

    class_methods do
      # return name of the handler with the prefix
      # @param prefix example: handle
      # @param klass example: Event::Name
      # @return handle_Event_Name
      def handler_name(prefix, klass)
        klass = klass.name unless klass.is_a?(String)
        name = klass.gsub("::","_") # Event::Name => Event_Name
        return "#{prefix}_#{name}" # handle_Event_Name
      end
    end

    included do
    end

    def call_event_handler_if_present(prefix, klass, *pars)
      name = self.class.handler_name(prefix, klass)
      if self.class.method_defined?(name)
        send(name, *pars)
      else
        nil
      end
    end

  end
end