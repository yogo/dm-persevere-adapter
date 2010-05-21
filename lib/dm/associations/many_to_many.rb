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
          assert_kind_of 'target', target, target_model
          lazy_load(source) unless loaded?(source)
          get!(source).replace([target])
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
          Extlib::Inflection.underscore(Extlib::Inflection.demodulize(source_model.name)).pluralize.to_sym
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

        alias :my_add :"<<"
        def <<(resource)
          my_add(resource)
          resource.send(relationship.inverse.name).my_add(source)
        end

        alias :my_push :push
        def push(*resources)
          resources.each do |r|
            my_add(r)
            r.send(relationship.inverse.name).my_add(source)
          end
        end

        def _save(safe)
          if @removed.any?
            @removed.all.send(safe ? :destroy : :destroy!)
          end
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
            set_default_attributes(resource)
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
