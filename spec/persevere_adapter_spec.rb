require File.dirname(__FILE__) + '/spec_helper' 
gem 'rspec'
require 'spec'

require DataMapper.root / 'lib' / 'dm-core' / 'spec' / 'adapter_shared_spec'
agg_dir = path_to("dm-aggregates", "0.10.2")[0]
require agg_dir / 'spec' / 'public' / 'shared' / 'aggregate_shared_spec'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/persevere_adapter'

require 'ruby-debug'

describe DataMapper::Adapters::PersevereAdapter do
  before :all do
    # This needs to point to a valid persevere server
    @adapter = DataMapper.setup(:default, { :adapter => 'persevere', :host => 'localhost', :port => '8080' })
    @repository = DataMapper.repository(@adapter.name)

    class ::Bozon
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
  
   it_should_behave_like 'An Adapter'
   
   describe 'migrations' do
     it 'should create the Bozon storage' do
       Bozon.auto_migrate!
       Bozon.auto_migrate_down!
     end
   
     it "should destroy Create then Remove the Bozon Storage" do
       @adapter.get_schema(Bozon.storage_name).should == false
       Bozon.auto_migrate_up!
       @adapter.get_schema(Bozon.storage_name).should_not == false
       Bozon.auto_migrate_down!
       @adapter.get_schema(Bozon.storage_name).should == false
     end
   
     describe '#put_schema' do
       it 'should create the json schema for the hash' do
         @adapter.put_schema(@test_schema_hash).should_not == false
       end 
   
       it 'should create the json schema for the hash under the specified project' do
         @adapter.put_schema(@test_schema_hash, "test").should_not == false
       end
   
       it 'should create the json schema for the hash under the specified project' do
         @adapter.put_schema(@test_schema_hash_alt).should_not == false
       end 
     end
   
     describe '#get_schema' do
       it 'should return all of the schemas (in json) if no name is provided' do
         result = @adapter.get_schema()
         result.should_not == false
         JSON.parse(result).class.should == Array
       end 
   
       it 'should return the json schema of the class specified' do
         result = @adapter.get_schema("Object")
         result.should_not == false
         JSON.parse(result)["id"].should == "Object"
       end
   
       # I don't think we need these tests.
       # it 'should return all of the schemas (in json) for a project if no name is provided' do
       #   result = @adapter.get_schema(nil, "Class")
       #   debugger
       #   result
       # end 
       #   
       # it 'should return all of the schemas (in json) if no name is provided' do
       #   @adapter.get_schema("Object", "Class")
       # end 
     end
   
     describe '#update_schema' do
       it 'should update a previously existing schema' do
         result = @adapter.update_schema(@test_schema_hash_mod)
         result.should_not == false
   
         @test_schema_hash_mod['id'].should match(JSON.parse(result)['id'])
       end
   
       it 'should update a previously created schema under the specified project' do
         result = @adapter.update_schema(@test_schema_hash_mod, "test")
         result.should_not == false
         @test_schema_hash_mod['id'].should match(JSON.parse(result)['id'])
       end
   
       it 'should update a previously created schema under the specified project' do
         result = @adapter.update_schema(@test_schema_hash_alt_mod)
         result.should_not == false
         @test_schema_hash_alt_mod['id'].should match(JSON.parse(result)['id'])
       end
     end
   
     describe '#delete_schema' do
       it 'should delete the specified schema' do
         @adapter.delete_schema(@test_schema_hash).should == true
       end
   
       it 'should delete the specified schema in the specified project' do
         @adapter.delete_schema(@test_schema_hash, "test").should == true
       end
   
       it 'should delete the specified schema in the specified project' do
         @adapter.delete_schema(@test_schema_hash_alt).should == true
       end
     end
   end

  describe 'aggregates' do
    it_should_behave_like 'It Has Setup Resources'
    before :all do
      @dragons   = Dragon.all
      @countries = Country.all
    end
    it_should_behave_like 'An Aggregatable Class'

#     it 'should have a test for aggregation show up' do
# #      debugger
#     end
  end

  describe 'limiting and offsets' do
    before(:all) do
      Bozon.auto_migrate!
      (0..99).each{|i| Bozon.create!(:author => i, :title => i)}
    end
    
    it "should limit" do
      result = Bozon.all(:limit => 2)
      result.length.should == 2
    end
    
    after(:all) do
      Bozon.auto_migrate_down!
    end
  end
end
