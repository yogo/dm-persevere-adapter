module DataMapper
  class Property

    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      json_hash = Hash.new
      json_hash = {      "type"      => tm[type][:primitive] }
      json_hash.merge!({ "optional"  => true })       unless required?
      json_hash.merge!({ "unique"    => true})        if     unique?
      json_hash.merge!({ "position"  => @position })  unless @position.nil?
      json_hash.merge!({ "prefix"    => @prefix })    unless @prefix.nil?
      json_hash.merge!({ "separator" => @separator }) unless @separator.nil?
      json_hash.merge!(  tm[type].reject{ |key,value| key == :primitive } )

      json_hash
    end
    
  end
end