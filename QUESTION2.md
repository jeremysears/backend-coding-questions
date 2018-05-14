# QUESTION 2

## Background

At Lookout, we take a data driven approach to security. In part, this means combining static and dynamic analysis of programs with real-world samples of their actions. This coding and design exercise
should give you a feel for the type of problems we work on.

In this coding question, we're looking to differentiate between the normal set of IPs that a client communicates with and abnormal ones that might indicate reaching out to a C&C server for instructions. The clients will be sending events to the server, each containing a [Protocol Buffer](https://code.google.com/p/protobuf/)-encoded description of the app in question and the IP address it connected to. See [ip_event.proto](ip_event.proto) for the protobuf definition. The server's job (and yours to implement) is to collect these events and respond to queries about them.

The [sample client](lib/lookout/backend_coding_questions/q1/client.rb) will simulate the stream of events from a variety of clients. The server should handle POSTs to '/events' with a Content-Type of 'application/octet-stream'

Once the client is done sending simulated events, it will make a call to the RESTful API to check that the server captured and analyzed the event stream correctly. The server should handle a GET to '/events/:app_sha256'. When called with a JSON accept header, it should return a description of all events for that app_sha256. This should be of the form:

    {
      'count':NUMBER_OF_EVENTS,
      'good_ips':LIST_OF_GOOD_IPS,
      'bad_ips':LIST_OF_BAD_IPS
    }

For a given app, this exercise assumes it will only hit hosts within a /28 CIDR netblock (and thus have 14 valid IPs that it might hit, accounting for gateway and network addresses). The server should determine which IPs make up that /28 and return them as good_ips, and any other IPs are returned as bad_ips.  The netblock containing the good_ips will be the most dense netblock for a particular app-sha -- the netblock with the most recorded ip events.

The server must also handle a DELETE to '/events'. This is used to reset counters and data in between test runs.

## Installation

1) Install [Ruby Version Manager](https://rvm.io/rvm/install) (RVM).
2) Use RVM to install the version of ruby that the repo uses:


    $ rvm install $(<.ruby_version)
    $ rvm gemset use $(<.ruby_gemset) --create

3) Build the client


    $ gem install bundler
    $ rake build
    $ gem install pkg/backend_coding_questions-0.0.*.gem

## Usage

    $ ./bin/lookout_backend_coding_q2_client --host HOST --tcp TCP_PORT

Note, you may see the following deprecation warning, but you can safely ignore it:


    ~/.rvm/gems/ruby-2.5.1@backend-coding-questions/gems/ruby_protobuf-0.4.11/lib/protobuf/message/enum.rb:49: warning: constant ::Fixnum is deprecated
