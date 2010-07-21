module DataMapper
  class Repository
    # Update the attributes of one or more resource instances
    #
    #   TODO: create example
    #
    # @param [Hash(Property => Object)] attributes
    #   hash of attribute values to set, keyed by Property
    # @param [Collection] collection
    #   collection of records to be updated
    #
    # @return [Integer]
    #   the number of records updated
    #
    # @api semipublic
    def update(attributes, collection)
      return 0 unless collection.query.valid?
      adapter.update(attributes, collection)
    end
  end
end