#
#  Yogo Data Management Toolkit : Persevere Wrapper
#  (c) 2008-2009 Montana State University
#  Ivan R. Judson
#
# This provides a relatively simple interface to access the Persevere
# JSON data store. More information about Persevere can be found here:
# http://www.persvr.org/
#
require 'net/http'
require 'uri'

require 'rubygems'
require 'json'

# Ugly Monkey patching because Persever uses non-standard content-range headers.
module Net
  module HTTPHeader
    alias old_content_range content_range
    # Returns a Range object which represents Content-Range: header field.
    # This indicates, for a partial entity body, where this fragment
    # fits inside the full entity body, as range of byte offsets.
    def content_range
      return nil unless @header['content-range']
       m = %r<bytes\s+(\d+)-(\d+)/(\d+|\*)>i.match(self['Content-Range']) or
           return nil
       m[1].to_i .. m[2].to_i + 1
    end

  end
end

class PersevereResult
  attr_reader :location, :code, :message, :body

  def PersevereResult.make(response)
    return PersevereResult.new(response["Location"], response.code,
                               response.msg, response.body)
  end

  def initialize(location, code, message, body)
    @location = location
    @code = code
    @message = message
    @body = body
  end

  def to_s
    super + " < Location: #{ @location } Code: #{ @code } Message: #{ @message } >"
  end
end

class Persevere
  HEADERS = { 'Accept' => 'application/json',
              'Content-Type' => 'application/json'
            } unless defined?(HEADERS)

  attr_accessor :server_url, :pservr


  def initialize(url)
    @server_url = url
    server = URI.parse(@server_url)
    @persevere = Net::HTTP.new(server.host, server.port)
  end

  # Pass in a resource hash
  def create(path, resource, headers = {})
    json_blob = resource.reject{|key,value| value.nil? }.to_json
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('POST', path, json_blob, HEADERS.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def retrieve(path, headers = {})
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('GET', path, nil, HEADERS.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Retrieve Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def update(path, resource, headers = {})
    json_blob = resource.to_json
#    puts "JSON to PERSEVERE: #{json_blob}"
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('PUT', path, json_blob, HEADERS.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def delete(path, headers = {})
    response = nil
#    puts "DELETING #{path}"
    while response.nil?
      begin
        response = @persevere.send_request('DELETE', path, nil, HEADERS.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end
end # class Persevere
