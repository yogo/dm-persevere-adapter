module DataMapper
  module Persevere
    module JSONSupport
      module Model
        module Relationships
          #TODO: Add various options in.
          def to_json_hash(repository_name = default_repository_name)
            schema_hash = super
            schema_hash['properties'] ||= {}
        
            # Handle relationships
            relationships.each_pair do |nom,relation|
              next if self.name.downcase == nom
              relation = Persevere.enhance(relation)
              schema_hash['properties'][nom] = relation.to_json_hash
            end
            return schema_hash
          end
        end # Relationships
      end # Model
    end # JSONSchema
  end # Persevere
end # DataMapper