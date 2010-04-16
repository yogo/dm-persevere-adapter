module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_compatible_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_compatible_hash(repository_name = default_repository_name)
        usable_properties = properties.select { |p| p.field != 'id' }
        schema_hash = {}
        schema_hash['id'] = self.storage_name(repository_name)
        properties_hash = {}
        usable_properties.each do |p| 
          properties_hash[p.field] = p.to_json_schema_hash(repository_name) 
        end
        schema_hash['properties'] = properties_hash
        schema_hash['prototype'] = {}
        return schema_hash
      end
  end

  class Property
    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      json_hash = {}
      
      if type.eql?(DataMapper::Types::JsonReference)
        json_hash = { "type" => {"$ref" => "../#{reference_class.storage_name}"}, "optional" => true }
      elsif type.eql?(DataMapper::Types::JsonReferenceCollection)
        json_hash = { "type" => "array", 
                      "optional" => true,  
                      "items" => {"$ref" => "../#{reference_class.storage_name}"}
                    }
        #  "maxItems" => # For 0..3 
        #  "minItems" =>
      else
        json_hash = { "type" => tm[type][:primitive] }
        json_hash.merge!( tm[type].reject{ |key,value| key == :primitive } )
        json_hash.merge!({ "optional" => true }) unless required?
        json_hash.merge!({ "unique"  => true})   if     unique?
        json_hash.merge!({"position" => @position }) unless @position.nil?
        json_hash.merge!({"prefix" => @prefix }) unless @prefix.nil?
        json_hash.merge!({"separator" => @separator }) unless @separator.nil?
      end
      
      # MIN
      # MAX
      json_hash
    end
    
  end
end