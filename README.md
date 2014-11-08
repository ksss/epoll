epoll
===

[![Build Status](https://travis-ci.org/ksss/epoll.svg?branch=master)](https://travis-ci.org/ksss/epoll)

An experimental binding of epoll(7).

**epoll(7)** can use Linux only. (because must be installed sys/epoll.h)

# Usage

```ruby
require 'epoll'

# Epoll < IO

# Epoll.create
#   call epoll_create(2)
#   it's just alias of `IO.open`
#   Epoll object stock a File Descriptor returned by epoll_create(2)
#   return: instance of Epoll
epoll = Epoll.create

# IO object add to interest list
#   call epoll_ctl(2)
epoll.add(io, Epoll::IN)  # same way to epoll.ctl(Epoll::CTL_ADD, io, Epoll::IN)

# change waiting events
#   call epoll_ctl(2)
epoll.mod(io, Epoll::OUT) # same way to epoll.ctl(Epoll::CTL_MOD, io, Epoll::OUT)

# remove from interest list
#   call epoll_ctl(2)
epoll.del(io)             # same way to epoll.ctl(Epoll::CTL_DEL, io)

loop do
  # Epoll#wait(timeout=-1)
  #   call epoll_wait(2)
  #   timeout = -1: block until receive event or signals
  #   timeout = 0: return all io's can I/O on non block
  #   timeout > 0: block when timeout pass miri second or receive events or signals
  #   return: Array of Epoll::Event
  evlist = epoll.wait

  # ev is instance of Epoll::Event like `struct epoll_event`
  # it's instance of `class Epoll::Event < Struct.new(:data, :events); end`
  evlist.each do |ev|
    # Epoll::Event#events is event flag bits (Fixnum)
    if (ev.events & Epoll::IN) != 0
      # Epoll::Event#data is notified IO (IO)
      # e.g. it's expect to I/O readable
      puts ev.data.read
    elsif (ev.events & Epoll::HUP|Epoll::ERR) != 0
      ev.data.close
      break
    end
  end
end

# you can close File Descriptor for epoll when finish to use
epoll.close #=> nil

# and you can check closed
epoll.closed? #=> true

# and very useful way is that call `create` (or `new`) with block like Ruby IO.open
# return: block result
Epoll.create do |epoll|
  # ensure automatic call `epoll.close` when out block
end
```

## ctl options

ctl options|description
---|---
**Epoll::CTL_ADD**|add to interest list for created epoll fd
**Epoll::CTL_MOD**|change io events
**Epoll::CTL_DEL**|delete in interest list

## Event flags

event flags|ctl|wait|description
---|---|---|---
**Epoll::IN**|o|o|readable
**Epoll::PRI**|o|o|high priority read
**Epoll::HUP**|o|o|peer socket was shutdown
**Epoll::OUT**|o|o|writable
**Epoll::ET**|o|x|use edge trigger
**Epoll::ONESHOT**|o|x|auto watching stop when notified(but stay in list)
**Epoll::ERR**|x|o|raise error
**Epoll::HUP**|x|o|raise hang up

see also **man epoll(7)**

## Installation

Add this line to your application's Gemfile:

    gem 'epoll'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install epoll

# Pro Tips

- Support call without GVL in CRuby (use rb\_thread\_call\_without\_gvl())
- Close on exec flag set by default if you can use (use epoll_create1(EPOLL_CLOEXEC))
- Epoll#wait max return array size is 256 on one time (of course, overflowing and then carried next)

# Fork Me !

This is experimental implementation.
I'm waiting for your idea and Pull Request !
