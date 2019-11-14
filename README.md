# ActiveAggregate
This plugin provides an implementation of event sourcing for rails.

It is extracted as a plugin from a private business application and has no automated tests 
yet.  

Event Sourcing works by recording all state transitions in event records instead of
database records. Based on the saved events, we derive the state of aggregates/models 
by applying the events to the models. 
 
`ActiveAggregate::Base` is a specialised `ActiveRecord::Base` class that 
allows to change it's state by applying events to it and does not allow to modify and save it's state.
(In contrast to `ActiveRecord::Base` that manages state by running save action on it's objects.) 

In EventSourcing, the only effect of any write logic is the creation of events such
as ObjectCreated, SalarySaved, UserRemoved.
  

## Usage

Here is a simple example application consisting of:
* events - representing application state changes. In the example we have a `Sale` 
that transitions from `new` to either `sold` or `cancelled` state. 
Events encapsulate write logic conditions via validations.  
* controllers - are responsible for the write logic that is either to create the events 
successfully or not at all. Once an object is stored it can is applied to all aggregates
that respond to it through the `handle Object` declaration. 
* aggregates - encapsulating the business logic of applying events to them. 

### Events
Simple offer and sale events: `OfferEvent` is created when we put an item for sale,
and `SoldEvent` is created when someone buys it. If the item is not sold, the owner can 
cancel it with `CancelEvent`. Logic for validating events is included in each event, 
@see `correct_seller` or `correct_sale` methdods.   

```ruby

class SaleBaseEvent < ActiveAggregate::EventBase
    def self.event_domain
      "sales"
    end

    def fresh_uuid
      "SALE"+SecureRandom.hex(4)
    end

    def sale
      @sale||=Sale.find_by_uuid(uuid)
    end

    # @return uuid if last aggregate is unfinished
    # otherwise return null 
    def last_new_uuid
        Sale.find_by(state: 'new').try(:uuid)
    end
end


class OfferEvent < SaleBaseEvent
    store :payload, accessors: [
       :seller,
       :item,
       :price
   ]
   validates :seller, presence: true
   validates :name, presence: true
   validates :price, numericality: true
  end
  
class SoldEvent < SaleBaseEvent
    store :payload, accessors: [
           :buyer,
           :price
    ]
    validates :buyer, presence: true
    validate :correct_sale
    def correct_sale
       errors.add :state, 'Not new' if sale.state != 'new'
    end

  end

  class CancelEvent < SaleBaseEvent
    store :payload, accessors: [
           :seller
    ]
    validates :seller, presence: true
    validate :correct_sale, :correct_seller
    def correct_sale
       errors.add :state, 'Not new' if sale.state != 'new'
    end
    def correct_seller
       errors.add :seller, 'Not owner' if sale.seller != seller
    end
  end

```

### Write logic

Controllers are responsible for the write operations. 
Each event basically needs an action for create, update or delete operation
that in the event sourced system is merely responsible for creating an event.
In the `SalesController` we see that each action cerates a corresponding event.

```ruby
class SalesController
  # POST /sales
  def create
    @event = OfferEvent.new(params.require(:event).permit(:seller, :name, :price))
    @event.save_and_apply
  end
  # DELTE /sales/:id
  def delete
    # Sale uuid is passed as id
    attrs = params.require(:event).permit(:seller).merge(uuid: id)
    @event = CancelEvent.new(attrs)
    @event.save_and_apply
  end  
  # PATCH /sales/:id
  def update
    # Sale uuid is passed as id
    attrs = params.require(:event).permit(:buyer).merge(uuid: id)
    @event = SoldEvent.new(attrs)
    @event.save_and_apply
  end
end
```

To make it easer, we can use a generic `EventController` that inherits from
 `ActiveAggregate::CreateEventController` and provides functionality 
 for saving an event and rendering it's view, or re-rendering the same
 view with an error message upon unsuccessful event save.
 
For each event we must define their views eg. `app/views/event/offer_event.html.erb` 
and we can optionally handle the `before` call that can be used to prepare event params,
and an `after` call that can be used for redirects. `after` action is triggered after successful
save of the event.   


```ruby
class EventsController < ActiveAggregate::CreateEventController

  before OfferEvent do |pars|
    pars        = pars.except(:uuid) # we don't use the uuid
    pars[:user] ||= used_email
    pars
  end

  after OfferEvent do |evt|
    set_used_email(evt.user)
    flash[:notice] = "Thank you"
    event_path("offer_sold") # redirect to OfferSold view
  end
end
```


### Business logic - event handlers/aggregates

Now let's see how we can apply the events to the aggregates. 
Because we must know what aggregates listen to events, we start by defining 
aggregate parent class that lists all aggregates for the events. 

EventHandlers/aggregates implement how individual events are applied to business models. 
They must inherit from `AggregateBase` and must be added to `self.all_handler_names`.
Each ActiveAggregate specifies what events they respond to via implementing `handle EventName` methods.

```ruby
# app/handlers/base_event_handler.rb
class AggregateBase < ActiveAggregate::Base
  # list names of all handlers
  # to be auto loaded at boot time
  def self.all_handler_names
    %w"Sale"
  end 
end
 
# app/models/sale.rb
class Sale < AggregateBase
  attributes :state, :seller, :name, :price  
  def listen_to_domains
    ['sales', 'tx'] # listen to both sales events and tx events
  end

  handle OfferEvent do |evemt|
    self.state   = 'new'
    self.seller  = event.seller
    self.name    = event.name
    self.price   = event.price
  end

  handle CancelEvent do |event|
    self.state = 'cancelled'
    self.cancelled_at = event.created_at
  end

  handle SoldEvent do |event|
    self.state = 'sold'
    self.sold_at = event.created_at
    self.buyer = event.buyer 
  end
end
```

After applying the events, aggregates are saved in the db and can be accessed as normal 
`ActiveRecord` objects like in the `SalesController`.

```ruby
class SalesController
  # GET /sales
  def index
    @events = Sale.all
  end
  # GET /sales/:id
  def show
    @event = Sale.find_by_uuid(params[:id])
  end  
end
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'active_aggregate'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install active_aggregate
```

## TODO 

- extend test coverage
- example test application
- migrations generator for aggregates

## Contributing

WIP

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
