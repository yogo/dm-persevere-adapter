module DataMapper
  module Resource

    def get_parent_objects
      grandpappy = parent_relationships.collect do |relationship|
        parent = relationship.get!(self)
        if parent.new?
          return [parent.__send__(:get_parent_objects), parent].flatten
        else
          return [parent.__send__(:get_parent_objects)].flatten
        end          
      end
    end

    def get_child_objects
      grandpappy = child_collections.collect do |collection|
        return collection.map {|c| c.new? ? [c.get_child_objects, c] : [c.get_child_objects]}.flatten
      end
    end

    def get_new_objects
      parents = get_parent_objects
      kids = get_child_objects
      self.new? ? [parents, self, kids].flatten : [parents, kids].flatten
    end

    def create_hook
      op = original_attributes.dup
      _create
      @_original_attributes = op.dup
    end

    alias _old_update _update

    def _update
      if repository.adapter.is_a?(DataMapper::Adapters::PersevereAdapter)
        # remove from the identity map
        remove_from_identity_map

        repository.update(dirty_attributes, collection_for_self)

        # remove the cached key in case it is updated
        remove_instance_variable(:@_key)

        add_to_identity_map

        true
      else
        _old_update
      end
    end

    #-----------------------------------------------------------------------------------------------------------

    alias _old_save _save

    def _save(safe)
      get_new_objects.each do |obj|
        obj.__send__(:save_self, safe)
      end
      _old_save(safe)
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
            # puts "Self: #{self.inspect}"
            # puts "Name: #{nom}"
            # puts "Value: #{value.inspect}"
            # puts "Parent: #{parent.inspect}"
            # puts "Child: #{child.inspect}"
            # puts "Relation: #{relation.inspect}"

            case relation
            when DataMapper::Associations::ManyToOne::Relationship
              if self.kind_of?(child)
#                puts "belongs_to"
                json_rsrc[nom] = { "$ref" => "../#{value.model.storage_name}/#{value.id}" }
              else
                puts "m2o: self != child"
              end
            when DataMapper::Associations::OneToMany::Relationship
              if self.kind_of?(child)
                puts "o2m: self = child"
              else
#                puts "o2m: self != child"
                json_rsrc[nom] = value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.id}" } }
              end
            when DataMapper::Associations::ManyToMany::Relationship
              if self.kind_of?(child)
                puts "m2m: self = child"
              else
#                puts "m2m: self != child"
                json_rsrc[nom] = value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.id}" } }
              end
            when DataMapper::Associations::OneToOne::Relationship
              if self.kind_of?(child)
                puts "o2o: self = child"
              else
#                puts "o2o: self != child"
                json_rsrc[nom] = value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.id}" } }
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
