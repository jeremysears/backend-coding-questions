require 'ipaddr'
require 'socket'
require 'json'
require 'securerandom'
require 'rest_client'
require 'forgery'

GOOD_RANGE = 14 # A /28 netblock, with gateway and network ips excluded
MAX_BAD_COUNT = 10 # H
MAX_EVENT_COUNT = 10 * 1000 * 1000 # How many UDP packets to send
EVENT_PERIOD = 0.00001 # Sleep between sending UDP packets to give server a chance to keep up

module Lookout::BackendCodingQuestions::Q1
  class Client
    def initialize(host, tcp_port, udp_port)
      @host = host
      @tcp_port = tcp_port
      @udp_port = udp_port
      @good_ip_base = IPAddr.new(Forgery(:internet).ip_v4)
      @app_sha256 = SecureRandom.hex(32)
    end

    # Start sending events, then check that they were receieved
    def run
      send_events
      response = get_event_status
      validate_response(response)
    end

    private

    # Returns a list of GOOD_RANGE IPAddrs
    def good_ips
      return @good_ips if defined?(@good_ips)
      @good_ips = []
      GOOD_RANGE.times {|n| @good_ips << IPAddr.new(@good_ip_base.to_i + n, Socket::AF_INET)}
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
          @events << event.serialize_to_string
        end
      end
      @events
    end

    # Send EVENT_COUNT events as UDP packets to @socket
    def send_events
      socket = UDPSocket.new(Socket::AF_INET)
      socket.connect(@host, @udp_port)

      @event_count = Random.rand(MAX_EVENT_COUNT)
      @event_count.times do
        socket.send(events.sample, 0)
        sleep(EVENT_PERIOD)
      end
    end

    # GET /events/@app_sha256 as parse result as JSON
    def get_event_status
      response = RestClient.get "http://#{@host}:#{@tcp_port}/events/#{@app_sha256}", {:accept => :json}
      raise "Invalid response from server: #{response.code}: #{response}" unless response.code == 200
      JSON.parse(response.body)
    end

    # Validate the JSON response has correct form and data:
    # {
    #  'count':NUMBER_OF_EVENTS,
    #  'good_ips':LIST_OF_GOOD_IPS,
    #  'bad_ips':LIST_OF_BAD_IPS
    # }
    def validate_response(json)
      puts "Received #{json.inspect}"
      raise "Unexpected response #{json.class}:#{json}" unless json.kind_of?(Hash)
      raise "Dropped too many packets: #{json['count']} out of #{@event_count}" unless
        json['count'] >= @event_count * 0.3 # Leave .03 fudge factor for dropped packets
      raise "No good IP list: #{json}" unless json['good_ips'].kind_of?(Array)
      raise "Good IP list didn't match: #{json['good_ips'].sort} != #{good_ips.sort}" unless json['good_ips'].sort == good_ips.sort
      raise "No bad IP list: #{json}" unless json['bad_ips'].kind_of?(Array)
      raise "Bad IP list didn't match: #{json['bad_ips'].sort} != #{bad_ips.sort}" unless json['bad_ips'].sort == bad_ips.sort
    end
  end
end
