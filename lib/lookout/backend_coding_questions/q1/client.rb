require 'ipaddr'
require 'socket'
require 'json'
require 'securerandom'
require 'rest_client'
require 'forgery'

GOOD_RANGE = 14 # A /28 netblock, with gateway and network ips excluded
MAX_BAD_COUNT = 10 # H
MAX_UDP_EVENT_COUNT = 10 * 1000 # Maximum number of UDP packets to send
MAX_REST_EVENT_COUNT = 10 * 1000 # Maximum number of RESTFul events to send
EVENT_PERIOD = 0.00001 # Sleep between sending UDP packets to give server a chance to keep up

module Lookout::BackendCodingQuestions::Q1
  class Client
    def initialize(host, tcp_port, udp_port)
      @host = host
      @tcp_port = tcp_port
      @udp_port = udp_port
      @good_ip_base = IPAddr.new(Forgery(:internet).ip_v4 + "/255.255.255.240")
      @app_sha256 = SecureRandom.hex(32)
    end

    # Start sending events, then check that they were receieved
    def run
      reset_server
      if @udp_port > 0
        good_count = send_events_udp
      else
        good_count = send_events_rest
      end
      response = get_event_status
      validate_response(response, good_count)
    end

    private

    # Tell the server to drop all events and reset counters
    def reset_server
      RestClient.delete "http://#{@host}:#{@tcp_port}/events"
    end

    # Returns a list of GOOD_RANGE IPAddrs
    def good_ips
      return @good_ips if defined?(@good_ips)
      @good_ips = []
      # Let's do an actual /28 block
      GOOD_RANGE.times {|n| @good_ips << IPAddr.new(@good_ip_base.to_i + n + 1, Socket::AF_INET)}
      @good_ips
    end

    # Returns a list of IPAddrs, none of which are within GOOD_RANGE of any address in `good_ips`
    def bad_ips
      return @bad_ips if defined?(@bad_ips)
      @bad_ips = []
      count = Random.rand(MAX_BAD_COUNT) + 1
      count.times { @bad_ips << IPAddr.new(Forgery(:internet).ip_v4) }
      @bad_ips.delete_if {|ip| (@good_ip_base.to_i - ip.to_i).abs < (GOOD_RANGE * 2)}
    end

    # Returns a list of up to serialized IpEvent objects, for
    # both good and bad IPs and for both @app_sha256 and other random
    # SHA256 values.
    def events
      return @events if defined?(@events)
      other_sha256 = SecureRandom.hex(32)
      final_sha256 = SecureRandom.hex(32)

      @events = []
      (good_ips + bad_ips).each do |ip|
        [@app_sha256, other_sha256, final_sha256].each do |sha256|
          event = IpEvent.new
          event.app_sha256 = sha256
          event.ip = ip.to_i
          # Protobuf encoding
          @events << {:data => event.serialize_to_string, :good => (sha256 == @app_sha256) }
        end
      end
      @events
    end

    # Send MAX_UDP_EVENT_COUNT events as UDP packets to @socket
    def send_events_udp
      socket = UDPSocket.new(Socket::AF_INET)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 1024 * 1024)
      socket.connect(@host, @udp_port)

      good_count = 0
      event_count = Random.rand(MAX_UDP_EVENT_COUNT)
      event_count.times do
        event = events.sample
        begin
          socket.send(event[:data], 0)
        rescue Errno::ENOBUFS
          puts "ENOBUFS, waiting"
          sleep(EVENT_PERIOD * 2)
          retry
        end
        sleep(EVENT_PERIOD)
        good_count += 1 if event[:good]
      end

      good_count
    end

    # Send MAX_TCP_EVENT_COUNT events as REST requests
    def send_events_rest
      good_count = 0
      event_count = Random.rand(MAX_REST_EVENT_COUNT)
      resource = RestClient::Resource.new("http://#{@host}:#{@tcp_port}/events",
                                          :timeout => 10)
      event_count.times do
        event = events.sample
        resource.post event[:data], {:content_type => 'application/octet-stream'}
        good_count += 1 if event[:good]
      end

      good_count
    end

    # GET /events/@app_sha256 as parse result as JSON
    def get_event_status
      begin
        response = RestClient.get "http://#{@host}:#{@tcp_port}/events/#{@app_sha256}", {:accept => :json}
        JSON.parse(response.body)
      rescue => e
        raise "Invalid response from server: #{e.inspect}"
      end
    end

    # Validate the JSON response has correct form and data:
    # {
    #  'count':NUMBER_OF_EVENTS,
    #  'good_ips':LIST_OF_GOOD_IPS,
    #  'bad_ips':LIST_OF_BAD_IPS
    # }
    def validate_response(json, good_count)
      puts "Received #{json.inspect}"
      raise "Unexpected response #{json.class}:#{json}" unless json.kind_of?(Hash)
      raise "No good IP list: #{json}" unless json['good_ips'].kind_of?(Array)
      raise "Good IP list didn't match: #{json['good_ips'].sort} != #{good_ips.map(&:to_s).sort}" unless json['good_ips'].sort == good_ips.map(&:to_s).sort
      raise "No bad IP list: #{json}" unless json['bad_ips'].kind_of?(Array)
      raise "Bad IP list didn't match: #{json['bad_ips'].sort} != #{bad_ips.map(&:to_s).sort}" unless json['bad_ips'].sort == bad_ips.map(&:to_s).sort

      actual_count = json['count'].to_i
      dropped = good_count - actual_count
      pct = actual_count * 100.0 / good_count
      puts "Dropped #{dropped} packets: Server handled #{actual_count} out of #{good_count} (%.4g%%)" % pct
    end
  end
end
