require File.dirname(__FILE__) + '/spec_helper' 
gem 'rspec'
require 'spec'
require 'dm-core'
require 'extlib'

require 'ruby-debug'

require DataMapper.root / 'lib' / 'dm-core' / 'spec' / 'adapter_shared_spec'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/persevere_adapter'

describe DataMapper::Adapters::PersevereAdapter do
  before :all do
    # This needs to point to a valid persevere server
    @adapter = DataMapper.setup(:default, { :adapter => 'persevere', :host => 'localhost', :port => '8080' })

    class Bozon
      include DataMapper::Resource

      # Persevere only does id's as strings.  
      property :id, String, :serial => true
      property :author, String
      property :created_at, DateTime
      property :title, String
    end

    @test_schema_hash = {
      'id' => 'Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      }
    }

    @test_schema_hash_alt = {
      'id' => 'test1/Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      }
    }
    @test_schema_hash_mod = {
      'id' => 'Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'newdata' => { 'type' => 'any'}
      }
    }

    @test_schema_hash_alt_mod = {
      'id' => 'test1/Vanilla',
      'properties' => {
        'cid' => {'type' => 'string' },
        'newdata' => { 'type' => 'any'}
      }
    }
  end

  describe 'migrations' do
    it 'should create the book storage' do
      debugger
      Bozon.auto_migrate!
    end
  end

  it_should_behave_like 'An Adapter'

  describe '#put_schema' do
    it 'should create the json schema for the hash' do
      @adapter.put_schema(@test_schema_hash)
    end 

    it 'should create the json schema for the hash under the specified project' do
      @adapter.put_schema(@test_schema_hash, "test")
    end

    it 'should create the json schema for the hash under the specified project' do
      @adapter.put_schema(@test_schema_hash_alt)
    end 
  end

  describe '#get_schema' do
    it 'should return all of the schemas (in json) if no name is provided' do
      @adapter.get_schema()
    end 

    it 'should return the json schema of the class specified' do
      @adapter.get_schema("Object")
    end

    it 'should return all of the schemas (in json) for a project if no name is provided' do
      @adapter.get_schema(nil, "Class")
    end 

    it 'should return all of the schemas (in json) if no name is provided' do
      @adapter.get_schema("Object", "Class")
    end 
  end

  describe '#update_schema' do
    it 'should update a previously existing schema' do
      @adapter.update_schema(@test_schema_hash_mod)
    end

    it 'should update a previously created schema under the specified project' do
      @adapter.update_schema(@test_schema_hash_mod, "test")
    end

    it 'should update a previously created schema under the specified project' do
      @adapter.update_schema(@test_schema_hash_alt_mod)
    end
  end

  describe '#delete_schema' do
    it 'should delete the specified schema' do
      @adapter.delete_schema(@test_schema_hash)
    end

    it 'should delete the specified schema in the specified project' do
      @adapter.delete_schema(@test_schema_hash, "test")
    end

    it 'should delete the specified schema in the specified project' do
      @adapter.delete_schema(@test_schema_hash_alt)
    end
  end
end
