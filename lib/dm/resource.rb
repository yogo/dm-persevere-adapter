module DataMapper
  module Resource
    
    def dirty_self?
      true
    end
    
    # @api private
    def _save(safe)
      _op = self.original_attributes.dup   
            
      # Go through and create all the objects in the first pass
      run_once(true) do
        save_parents(safe) && save_self(safe) 
        @_original_attributes = _op.dup
        save_children(safe)
      end
    
#    debugger
    
      # Second pass should create all the relationships
      run_once(true) do        
        @_original_attributes = _op.dup
        save_parents(safe)
        @_original_attributes = _op.dup
        save_self(safe)
        @_original_attributes = _op.dup
        save_children(safe)
      end
    end

    ##
    # Convert a DataMapper Resource to a JSON.
    #
    # @param [Query] query
    #   The DataMapper query object passed in
    #
    # @api semipublic
    def to_json_hash(include_relationships=true)
      json_rsrc = Hash.new
      relations = self.model.relationships.keys

      
      self.model.relationships.values do |relation|
        relation.child_key
      end
      
      if include_relationships
        self.model.relationships.each do |nom, relation|

          value = relation.get!(self)
          parent = relation.parent_model
          child = relation.child_model

          unless value.nil?
            puts "Self: #{self.inspect}"
            puts "Name: #{nom}"
            puts "Value: #{value.inspect}"
            puts "Parent: #{parent.inspect}"
            puts "Child: #{child.inspect}"
            puts "Relation: #{relation.inspect}"

            case relation
            when DataMapper::Associations::ManyToOne::Relationship
              if self.kind_of?(child)
                puts "belongs_to"
                json_rsrc[nom] = { "$ref" => "../#{value.model.storage_name}/#{value.id}" }
              else
                puts "m2o: self != child"
              end
            when DataMapper::Associations::OneToMany::Relationship
              if self.kind_of?(child)
                puts "o2m: self = child"
              else
                puts "o2m: self != child"
                json_rsrc[nom] = value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.id}" } }
              end
            when DataMapper::Associations::ManyToMany::Relationship
              if self.kind_of?(child)
                puts "m2m: self = child"
              else
                puts "m2m: self != child"
              end
            when DataMapper::Associations::OneToOne::Relationship
              if self.kind_of?(child)
                puts "o2o: self = child"
              else
                puts "o2o: self != child"
              end
            end
          end
        end
      end

      attributes(:property).each do |property, value|
        next if value.nil? || (value.is_a?(Array) && value.empty?) || relations.include?(property.name.to_s)

        json_rsrc[property.field] = case value
        when DateTime then value.new_offset(0).strftime("%Y-%m-%dT%H:%M:%SZ")
        when Date then value.to_s
        when Time then value.strftime("%H:%M:%S")
        when Float then value.to_f
        when BigDecimal then value.to_f
        when Integer then value.to_i
        else # when String, TrueClass, FalseClass then
          self[property.name]
        end
      end

      json_rsrc
    end
  end
end
