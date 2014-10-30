io-epoll
===

An experimental binding of epoll(7).

**epoll(7)** can use Linux only. (because must be installed sys/epoll.h)

# Usage

```ruby
require 'io/epoll'

IO.epoll([io1, io2, io3], Epoll::IN) do |ev|
  # ev is IO::Epoll::Event object like `struct epoll_event`
  # it's have data and events properties

  # events is event flag bits (Fixnum)
  events = ev.events

  # data is notificated IO (IO)
  data = ev.data
end

# on other way, you can make instance of IO::Epoll

Epoll = IO::Epoll

# IO::Epoll.create
#   run epoll_create(2)
#   it's just alias of `new`
epoll = Epoll.create

# IO::Epoll#ctl(option, io, flag)
#   run epoll_ctl(2)
#   option: you can choice epoll_ctl option in CTL_ADD, CTL_MOD and CTL_DEL.
#     CTL_ADD: add io list to watching for created epoll fd
#     CTL_MOD: you can change io events
#     CTL_DEL: delete io in watching list
#   io: set an IO object for watching.
#   flag: set flag bits like Epoll::IN|Epoll::OUT|Epoll::ONESHOT etc...
#     see also man epoll_ctl(2)
epoll.ctl(Epoll::CTL_ADD, io, Epoll::IN)

# and you can use short way
epoll.add(io, Epoll::IN)  # same way to epoll.ctl(Epoll::CTL_ADD, io, Epoll::IN)
epoll.mod(io, Epoll::OUT) # same way to epoll.ctl(Epoll::CTL_MOD, io, Epoll::IN)
epoll.del(io)             # same way to epoll.ctl(Epoll::CTL_DEL, io)

# IO::Epoll#wait(timeout=-1)
#   run epoll_wait(2)
#   timeout = -1: block until receive event or signals
#   timeout = 0: return all io's can I/O on non block
#   timeout > 0: block when timeout pass miri second or receive events or signals
evlist = epoll.wait
```

## Installation

Add this line to your application's Gemfile:

    gem 'io-epoll'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install io-epoll

# Fork me !

This is experimental implementation.
I'm waiting for your idea and Pull Request !
