module DataMapper
  module Associations
    class Relationship
      
      # Prefix
      # @example property.prefix
      # @return [String]
      # @api public
      attr_accessor :prefix
      
      def to_json_schema_hash
        child = self.child_model
        parent = self.parent_model
        relationship_schema = {}

        case self
        when DataMapper::Associations::ManyToMany::Relationship
         relationship_schema = { "type"     => "array", 
                                 "dm_relation" => "many_to_many",
                                 "lazy"     => true,
                                 "optional" => true,  
                                 "items"    => {"$ref" => "/Class/#{child.storage_name}"},
                                 "minItems" => self.min
          }
          relationship_schema["maxItems"] = self.max if self.max != Infinity
        when DataMapper::Associations::OneToMany::Relationship 
          relationship_schema = { "type"     => "array", 
                                  "dm_relation" => "has_n",
                                  "lazy"     => true,
                                  "optional" => true,  
                                  "items"    => {"$ref" => "/Class/#{child.storage_name}"},
                                  "minItems" => self.min
           }
           relationship_schema["maxItems"] = self.max if self.max != Infinity
         when DataMapper::Associations::ManyToOne::Relationship
           relationship_schema = { "type" => { "$ref" => "/Class/#{parent.storage_name}" }, 
                                   "dm_relation" => "belongs_to",
                                   "lazy" => true, 
                                   "optional" => true }
        when DataMapper::Associations::OneToOne::Relationship
          relationship_schema = { "type" => { "$ref" => "/Class/#{child.storage_name}" }, 
                                  "dm_relation" => "has_n",
                                  "lazy" => true, 
                                  "optional" => true }
        end
        
        relationship_schema.merge!("prefix" => @prefix ) unless @prefix.nil?
        return relationship_schema
        
      end
    end
  end
end
