module DataMapper
  module Model
    # module Json
      def to_json_schema(repository_name = default_repository_name)
        to_json_schema_hash(repository_name).to_json
      end
      
      #TODO: Add various options in.
      def to_json_schema_hash(repository_name = default_repository_name)
        schema_hash               = {
                                      'id' => self.storage_name(repository_name),
                                      'prototype'  => Hash.new,
                                      'properties' => Hash.new
                                    }

        # Handle properties
        properties.select { |prop| prop.field != 'id' }.each do |prop| 
          schema_hash['properties'][prop.field] = prop.to_json_schema_hash(repository_name) 
        end
        
        # Handle relationships
        relationships.each_pair do |nom,relation|
          next if self.name.downcase == nom
          schema_hash['properties'][nom] = relation.to_json_schema_hash
        end
        return schema_hash
      end
  end
end