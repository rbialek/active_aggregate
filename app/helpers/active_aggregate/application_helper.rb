module ActiveAggregate
  module ApplicationHelper

    def event_form(opts = {}, event = @event, &code)
      pars = {
          remote: true,
          path: save_event_path(event),
          class: 'form-fields',
          id:   "form_" + event_type_name(event)
      }.merge(opts)

      content_tag(:div, id: event_type_name(event.class)) do
        form_for :event, pars, &code
      end
    end

    def save_event_path(kl)
      kl = kl.class.name unless kl.is_a?(String)
      "#{kl.to_s.underscore}"
    end

  end
end
