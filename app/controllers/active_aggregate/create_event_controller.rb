module ActiveAggregate
  class CreateEventController < ::ApplicationController
    helper ActiveAggregate::ApplicationHelper
    include ActiveAggregate::EventHandlerUtils

    layout :default_layout

    # GET /events/:type/new
    def new
      @event = new_event(event_params)
      #render event_view_path
      render :new
    end

    # POST /events/:type/
    def create
      @event = new_event(event_params)
      if @event.save_and_apply
        path = apply_after_create(@event)
        redirect_to path and return if path
      else
        render :errors
      end
    end

    protected

    # add handler based on the event class name
    # handle Event::EventName will create method:
    # def handle_Event_EventName(evt) ... end
    # @return params hash for the new event
    def self.before(klass, &code)
      name = handler_name("before", klass)
      define_method(name, &code) # befofe_name method
    end

    # Define a block to be executed after successful save
    # @return a redirect_to path
    # or nil
    def self.after(klass, &code)
      name = handler_name("after", klass)
      define_method(name, &code) # after_name method
    end

    helper_method :event_class_name, :event_type_name

    # Event::SomeType => some_type
    def event_type_name(klass = params[:type])
      klass.to_s.underscore.split("/").last #.gsub('/', '_')
    end

    def event_class_name(klass = params[:type])
      klass.camelize
    end

    def event_class
      event_class_name.constantize
    rescue # when creating event view without a class
      ActiveAggregate::EventDummy
    end

    def default_layout
      name = "layout_#{event_type_name}"
      if self.class.method_defined?(name)
        send(name, pars)
      else
        nil
      end
    end

    def new_event(pars = {})
      event_class.safe_new(pars)
    end

    def event_params
      @next_step = params.delete(:next)
      if params[:event]
        pars = params.require(:event).permit!
      else
        pars = {}
      end
      pars[:uuid] ||= params[:id]
      apply_before_params(pars)
    end

    private

    def apply_before_params(pars)
      ret = call_event_handler_if_present("before", event_class, pars)
      ret || pars
    end

    def apply_after_create(evt)
      call_event_handler_if_present("after", event_class, evt)
    end

  end
end
