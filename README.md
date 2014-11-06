io-epoll
===

[![Build Status](https://travis-ci.org/ksss/io-epoll.svg?branch=master)](https://travis-ci.org/ksss/io-epoll)

An experimental binding of epoll(7).

**epoll(7)** can use Linux only. (because must be installed sys/epoll.h)

# Usage

```ruby
require 'io/epoll'

# Recommend short hand
Epoll = IO::Epoll

# IO::Epoll.create
#   call epoll_create(2)
#   it's just alias of `new`
#   Epoll object stock a File Descriptor returned by epoll_create(2)
#   return: instance of IO::Epoll
epoll = Epoll.create

# IO::Epoll#ctl(option, io, flag)
#   call epoll_ctl(2)
#   option: you can choice options (see ctl options).
#   io: set an IO object for watching.
#   flag: set flag bits like Epoll::IN|Epoll::OUT|Epoll::ONESHOT etc...
#     see also man epoll_ctl(2)
#   return: self
epoll.ctl(Epoll::CTL_ADD, io, Epoll::IN)

# and you can use short way

# IO object add to interest list
epoll.add(io, Epoll::IN)  # same way to epoll.ctl(Epoll::CTL_ADD, io, Epoll::IN)

# change waiting events
epoll.mod(io, Epoll::OUT) # same way to epoll.ctl(Epoll::CTL_MOD, io, Epoll::OUT)

# remove from interest list
epoll.del(io)             # same way to epoll.ctl(Epoll::CTL_DEL, io)

loop do
  # IO::Epoll#wait(timeout=-1)
  #   call epoll_wait(2)
  #   timeout = -1: block until receive event or signals
  #   timeout = 0: return all io's can I/O on non block
  #   timeout > 0: block when timeout pass miri second or receive events or signals
  #   return: Array of IO::Epoll::Event
  evlist = epoll.wait

  # ev is instance of IO::Epoll::Event like `struct epoll_event`
  # it's instance of `class IO::Epoll::Event < Struct.new(:data, :events); end`
  evlist.each do |ev|
    # IO::Epoll::Event#events is event flag bits (Fixnum)
    if (ev.events & Epoll::IN) != 0
      # IO::Epoll::Event#data is notified IO (IO)
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
**IO::Epoll::CTL_ADD**|add to interest list for created epoll fd
**IO::Epoll::CTL_MOD**|change io events
**IO::Epoll::CTL_DEL**|delete in interest list

## Event flags

event flags|ctl|wait|description
---|---|---|---
**IO::Epoll::IN**|o|o|readable
**IO::Epoll::PRI**|o|o|high priority read
**IO::Epoll::HUP**|o|o|peer socket was shutdown
**IO::Epoll::OUT**|o|o|writable
**IO::Epoll::ET**|o|x|use edge trigger
**IO::Epoll::ONESHOT**|o|x|auto watching stop when notified(but stay in list)
**IO::Epoll::ERR**|x|o|raise error
**IO::Epoll::HUP**|x|o|raise hang up

see also **man epoll(7)**

## Installation

Add this line to your application's Gemfile:

    gem 'io-epoll'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install io-epoll

# Pro Tips

- Support call without GVL in CRuby (use rb\_thread\_call\_without\_gvl())
- Close on exec flag set by default if you can use (use epoll_create1(EPOLL_CLOEXEC))
- IO::Epoll#wait max return array size is 256 on one time (of course, overflowing and then carried next)

# Fork Me !

This is experimental implementation.
I'm waiting for your idea and Pull Request !
