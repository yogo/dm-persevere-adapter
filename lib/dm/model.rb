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
          child = relation.child_model
          parent = relation.parent_model

          case relation
            when DataMapper::Associations::OneToMany::Relationship, DataMapper::Associations::ManyToMany::Relationship
              schema_hash['properties'][nom] = { "type"     => "array", 
                                                 "lazy"     => true,
                                                 "optional" => true,  
                                                 "items"    => {"$ref" => "/Class/#{child.storage_name}"},
                                                 "minItems" => relation.min,
                                               }
                                               
              schema_hash['properties'][nom]["maxItems"] = relation.max if relation.max != Infinity 
            when DataMapper::Associations::ManyToOne::Relationship, DataMapper::Associations::OneToOne::Relationship
              if self == relation.child_model
                ref = "/Class/#{parent.storage_name}"
              else
                ref = "/Class/#{child.storage_name}"
              end
              schema_hash['properties'][nom] = { "type" => { "$ref" => ref }, "lazy" => true, "optional" => true }
          end
        end
        return schema_hash
      end
  end
end