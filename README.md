# Lookout::BackendCoding1

## Background

At Lookout, we take a data driven approach to security. In part, this means combining static and dynamic analysis of programs with real-world samples of their actions. This coding and design exercise
should give you a feel for the type of problems we work on.

In this coding question, we're looking to differentiate between the normal set of IPs that a client communicates with and abnormal ones that might indicate reaching out to a C&C server for instructions. The clients will be sending UDP packets to the server, each containing a Protobuf-encoded description of the app in question and the IP address it connected to. See [ip_event.proto](ip_event.proto) for the protobuf definition. The server's job (and yours to implement) is to collect these events, then implement a RESTful API to return data about those events.

The [sample client](lib/lookout/backend_coding_1/client.rb) will simulate the stream of events from a variety of clients. Once the client is done sending simulated events, it will make a call to the RESTful API to check that the server captured and analyzed the event stream correctly.

The server should handle a GET to '/events/:app_sha256'. When called with a JSON accept header, it should return a description of all events for that app_sha256. This should be of the form:

    {
      'count':NUMBER_OF_EVENTS,
      'good_ips':LIST_OF_GOOD_IPS,
      'bad_ips':LIST_OF_BAD_IPS
    }

For a given app, this exercise assumes it will only hit hosts within a /28 netblock (and thus have 14 valid IPs that it might hit, accounting for gateway and network addresses). The server should determine which IPs make up that /28 and return them as good_ips, and any other IPs are returned as bad_ips.

## Scaling considerations

This client will send about 33,000 UDP packets per second for five minutes (10 million events total). Your solution must handle this volume, but please also think about how you'd handle larger volumes and faster rates. You don't necessarily need to implement this, but please include an explanation about how to scale a solution. We also expect to see automated tests for your code, as we expect for all work.

## Installation

    $ rake build
    $ gem install pkg/lookout-backend_coding_1.gem

## Usage

    $ ./bin/lookout-backend_coding_1_client --host HOST --tcp TCP_PORT --udp UDP_PORT

## Submitting your code

Please send your Lookout contact a copy of your code (github link to your own repo or tarball) as well as a pointer to a publicly hosted server where your code is running (Heroku, AWS, etc) along with the ports that it's listening on. Please feel free to use your choice of language and framework. Please also include instructions on compiling and running your code.