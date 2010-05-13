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
          child = relation.child_model
          parent = relation.parent_model

          # I have a nagging feeling the "directionality" of relationships and the fact that they kind of 
          # sometimes go both directions, but not always is going to crop up and bite us until we have 
          # very thorough tests in place. It feels like those tests should be in dm-core however. IRJ
          case relation
            when DataMapper::Associations::OneToMany::Relationship || 
                 DataMapper::Associations::ManyToMany::Relationship
              schema_hash['properties'][nom] = { "type"     => "array", 
                                                 "optional" => true,  
                                                 "items"    => {"$ref" => "../#{child.storage_name}"},
                                                 "minItems" => relation.min,
                                               }
                                               
              schema_hash['properties'][nom]["maxItems"] = relation.max if relation.max != Infinity 
            when DataMapper::Associations::ManyToOne::Relationship || DataMapper::Associations::OneToOne::Relationship
              if self == relation.child_model
                ref = "../#{parent.storage_name}"
              else
                ref = "../#{child.storage_name}"
              end
              schema_hash['properties'][nom] = { "type" => { "$ref" => ref }, "optional" => true }
          end
        end
        return schema_hash
      end
  end
end