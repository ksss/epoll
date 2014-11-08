#! /usr/bin/env ruby

require 'epoll'
require 'socket'

server = TCPServer.open(4000)
puts "run http://127.0.0.1:4000/"

response = [
  "HTTP/1.0 200 OK\r\n",
  "Content-Length: 5\r\n",
  "Content-Type: text/html\r\n",
  "\r\n",
  "HELLO\r\n",
].join("")

ep = Epoll.create
ep.add server, Epoll::IN

Signal.trap(:INT) {
  ep.close
  server.close
}

loop do
  ep.wait.each do |ev|
    data = ev.data
    events = ev.events

    if data == server
      socket = server.accept
      ep.add socket, Epoll::IN|Epoll::ET
    elsif (events & Epoll::IN) != 0
      data.recv(1024)
      ep.mod data, Epoll::OUT|Epoll::ET
    elsif (events & Epoll::OUT) != 0
      data.puts response
      ep.del data
      data.close
    elsif (events & (Epoll::HUP|Epoll::ERR)) != 0
      p "Epoll::HUP|Epoll::ERR"
    else
      raise IOError
    end
  end
end
