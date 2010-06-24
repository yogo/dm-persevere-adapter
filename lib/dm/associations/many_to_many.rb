module DataMapper
  module Associations
    module ManyToMany #:nodoc:
      class Relationship < Associations::OneToMany::Relationship

        OPTIONS.delete(:via)
        OPTIONS.delete(:through)

        remove_method :through
        remove_method :via
        remove_method :lazy_load
        remove_method :source_scope
        remove_method :inverted_options
        remove_method :valid_target?
        remove_method :valid_source?

        # 
        # @api private
        def query
          @query
        end

        def set(source, target)
          assert_kind_of 'source',  source,  source_model
          assert_kind_of 'target', target, Array
          target.each {|item| assert_kind_of 'target array element', item, target_model }
          lazy_load(source) unless loaded?(source)
          # NOTE: This seems semantically wrong, a set should just erase the contents, 
          # not calculate the difference and replace the common elements...
          get!(source).replace(target)
        end
        
        # Loads association targets and sets resulting value on
        # given source resource
        #
        # @param [Resource] source
        #   the source resource for the association
        #
        # @return [undefined]
        #
        # @api private
        def lazy_load(source)
          
          # SEL: load all related resources in the source collection
          collection = source.collection
          
          # if source.saved? && collection.size > 1 #OLD LINE --IRJ
          if source.saved?
            eager_load(collection)
          end

          unless loaded?(source)
            set!(source, collection_for(source))
          end
        end
         
         # Eager load the collection using the source as a base
         #
         # @param [Collection] source
         #   the source collection to query with
         # @param [Query, Hash] query
         #   optional query to restrict the collection
         #
         # @return [Collection]
         #   the loaded collection for the source
         #
         # @api private
         def eager_load(source, query = nil)

           targets = source.model.all(query_for(source, query))
         
           # FIXME: cannot associate targets to m:m collection yet, maybe we fixed it.
           # if source.loaded? && !source.kind_of?(ManyToMany::Collection) WE CHANGED THIS: IRJ/RL
           if source.loaded?
             associate_targets(source, targets)
           end
         
           targets
         end

         def associate_targets(source, targets)
           # TODO: create an object that wraps this logic, and when the first
           # kicker is fired, then it'll load up the collection, and then
           # populate all the other methods
           target_maps = Hash.new { |hash, key| hash[key] = [] }

           targets.each do |target|
             target_maps[target_key.get(target)] << target
           end

           Array(source).each do |source|
             key = source_key.get(source)
             # eager_load_targets(source, target_maps[key], query)

             set!(source, collection_for(source, query).set(targets))
           end
         end

        private

        # Returns the inverse relationship class
        #
        # @api private
        def inverse_class
          self.class
        end

        def inverse_name
          self.prefix = "" if self.prefix.nil? 
          (self.prefix + Extlib::Inflection.underscore(Extlib::Inflection.demodulize(source_model.name)).pluralize).to_sym
        end

        # @api private
        def invert
          inverse_class.new(inverse_name, parent_model, child_model, inverted_options)
        end

        # @api semipublic
        def initialize(name, target_model, source_model, options = {})
          options.delete(:through)
          super
        end

        # Returns collection class used by this type of
        # relationship
        #
        # @api private
        def collection_class
          ManyToMany::Collection
        end
      end # class Relationship

      class Collection < Associations::OneToMany::Collection
        remove_method :_save
        remove_method :_create

        def inverse_add(*resources)
          resources.each do |r|
            r.send(relationship.inverse.name)._original_add(source)
          end
        end

        alias :_original_add :"<<"
        def <<(resource)
          resource.send(relationship.inverse.name)._original_add(source)
          _original_add(resource)
        end
        
        alias :_original_concat :concat
        def concat(resources)
          inverse_add(*resources)
          _original_concat(resources)
        end
        
        alias :_original_push :push
        def push(*resources)
          inverse_add(*resources)
          _original_push(*resources)
        end
        
        
        alias :_original_unshift :unshift
        def unshift(*resources)
          inverse_add(*resources)
          _original_unshift(*resources)
        end
        
        alias :_original_insert :insert
        def insert(offset, *resources)
          inverse_add(*resources)
          _original_insert(offset, *resources)
        end
        
        alias :_original_delete :delete
        def delete(resource)
          result = _original_delete(resource)
          resource.send(relationship.inverse.name)._original_delete(source)
          result
        end
        
        alias :_original_pop :pop
        def pop(*)
          removed = _original_pop
          removed._original_delete(source) unless removed.nil?
          removed
        end
        
        alias :_original_shift :shift
        def shift(*)
          removed = _original_pop
          removed._original_delete(source) unless removed.nil?
          removed
        end
        
        alias :_original_delete_at :delete_at
        def delete_at(offset)
          resource = _original_delete_at(offset)
          resource._original_delete(source) unless removed.nil?
          resource
        end
        
        # alias :_original_delete_if :delete_if
        def delete_if
          results = super { |resource| yield(resource) && resource_removed(resource) }
          results.each{|r| r._original_delete(source) }
          results
        end
        
        def reject!
          results = super { |resource| yield(resource) && resource_removed(resource) }
          results.each{|r| r._original_delete(source) }
          results
        end
         
        def replace(other)
          other = resources_added(other)
          removed = entries - other
          new_resources = other - removed
          resources_removed(removed)
          removed.each{ |r| delete(r) }
          new_resources.each do |resource| 
            resource.send(relationship.inverse.name)._original_add(source)
            _original_add(resource)
          end
          super(other)
        end
        
        alias :_original_clear :clear
        def clear
          self.each{|r| r._original_delete(source) }
          _original_clear
        end
         
        # TODO: Add these
        # slice!, splice, collect!

        def _save(safe)
          loaded_entries = self.loaded_entries
          @removed.clear
          loaded_entries.all? { |resource| resource.__send__(safe ? :save : :save!) }
        end
        
        private

        # Track the added resource
        #
        # @param [Resource] resource
        #   the resource that was added
        #
        # @return [Resource]
        #   the resource that was added
        #
        # @api private
        def resource_added(resource)
          resource = initialize_resource(resource)

          if resource.saved?
            @identity_map[resource.key] = resource
            @removed.delete(resource)
          else
            resource.save
          end
          resource
        end

        # @api private
        def resource_removed(resource)
          if resource.saved?
            @identity_map.delete(resource.key)
            @removed << resource
          end

          resource
        end
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
