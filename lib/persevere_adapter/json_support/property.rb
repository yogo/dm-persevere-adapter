module DataMapper
  module Persevere
    module JSONSupport
      module Property
        def to_json_hash(repo)
          tm = repository(repo).adapter.type_map
          type_information = tm[primitive]
          
          json_hash = Hash.new
          json_hash = {      "type"      => type_information[:primitive] }
          json_hash.merge!({ "optional"  => true })       unless required?
          json_hash.merge!({ "unique"    => true})        if     unique?
          json_hash.merge!({ "position"  => @position })  unless @position.nil?
          json_hash.merge!({ "prefix"    => @prefix })    unless @prefix.nil?
          json_hash.merge!({ "separator" => @separator }) unless @separator.nil?
          json_hash.merge!(  type_information.reject{ |key,value| key == :primitive } )

          json_hash
        end
      end # Property
    end # JSON
  end # Persevere
end # DataMapper