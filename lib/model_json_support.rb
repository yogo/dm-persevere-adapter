module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_compatible_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_compatible_hash(repository_name = default_repository_name)
        usable_properties = properties.select{|p| p.name != :id }
        schema_hash = {}
        schema_hash['id'] = self.storage_name(repository_name)
        properties_hash = {}
        usable_properties.each{|p| properties_hash[p.name] = p.to_json_schema_hash if p.name != :id }
        schema_hash['properties'] = properties_hash
        return schema_hash
      end

  end
  
  class Property
    def to_json_schema_hash
      json_hash = { "type" => to_json_type }
      json_hash.merge!({ "optional" => true }) unless required? == true
      # MIN
      # MAX
      json_hash
    end
    
    private
    
    def to_json_type
      # A case statement doesn't seem to be working when comparing classes.
      # That's why we're using a if elseif block.
      if type == DataMapper::Types::Serial
        return "string"
      elsif type == String
        return "string"
      elsif type == Float
        return "number"
      elsif type == DataMapper::Types::Boolean
        return "boolean"
      elsif type == DataMapper::Types::Text
        elsif type == "string"
      elsif type == Integer
        return "integer"
      else 
        return"string"
      end
    end
  end
end