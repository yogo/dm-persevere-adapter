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

  attr_accessor :server_url, :persevere

  def initialize(url)
    @server_url = url
    server = URI.parse(@server_url)
    @base_uri = server.path || ''
    @persevere = Net::HTTP.new(server.host, server.port)
    @client_id = "dm-persevere-adapter-#{(rand*1000)}" # just need a small random string
    @sequence_id = 0
  end

  # Pass in a resource hash
  def create(path, resource, headers = {})
    path = @base_uri + path
    if headers.has_key?('Content-Type') && headers['Content-Type'] != 'application/json'
      json_blob = resource
    else
      json_blob = resource.delete_if{|key,value| value.nil? }.to_json
    end
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('POST', URI.encode(path), json_blob, default_headers.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def retrieve(path, headers = {})
    path = @base_uri + path
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('GET', URI.encode(path), nil, default_headers.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Retrieve Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def update(path, resource, headers = {})
    path = @base_uri + path
    json_blob = resource.to_json
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('PUT', URI.encode(path), json_blob, default_headers.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end

  def delete(path, headers = {})
    path = @base_uri + path
    response = nil
    while response.nil?
      begin
        response = @persevere.send_request('DELETE', URI.encode(path), nil, default_headers.merge(headers))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "Persevere Create Failed: #{e}, Trying again."
      end
    end
    return PersevereResult.make(response)
  end
  
  private
  
  def default_headers
    @sequence_id += 1
    HEADERS.merge( {'Seq-Id' => @sequence_id.to_s, 'Client-Id' => @client_id } )
  end
  
end # class Persevere
