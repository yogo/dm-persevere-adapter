module DataMapper
  module Persevere
    module JSONSupport
      module Model
        module Properties
          #TODO: Add various options in.
          def to_json_hash(repository_name = default_repository_name)
            schema_hash = super
            schema_hash['properties'] ||= {}
            
            # Handle properties
            properties.select { |prop| prop.field != 'id' }.each do |prop| 
              prop = Persevere.enhance(prop)
              schema_hash['properties'][prop.field] = prop.to_json_hash(repository_name) 
            end
          
            return schema_hash
          end
        end # Properties
      end # Model
    end # JSON
  end # Persevere
end # DataMapper