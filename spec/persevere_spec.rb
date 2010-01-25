require File.dirname(__FILE__) + '/spec_helper'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/persevere'

describe Persevere do
  #
  # Create an object to interact with Persevere
  #
  before :all do
    @p = Persevere.new('http://localhost:8080')

    @blobObj = {
      'id' => 'Yogo',
      'properties' => {
        'cid' => {'type' => 'string', 'optional' => true },
        'parent' => { 'type' => 'string', 'optional' => true},
        'data' => { 'type' => 'string', 'optional' => true}
      }
    }
    
    @corruptObj = {
      'id' => 'Corrupt',
      'properties' => {
        'id' => 1234,
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      }
    }
    
    @mockObj = {
      'id' => 'Yogo',
      'properties' => {
        'cid' => {'type' => 'string', 'optional' => true },
        'parent' => { 'type' => 'string', 'optional' => true},
        'data' => { 'type' => 'string', 'optional' => true}
      },
      'prototype' => {}
    }
    
    @object = {
      'cid' => '123',
      'parent' => 'none',
      'data' => 'A Chunk Of Data'
    }
    
  end
  
  
  # Test POST to create a new class
  
  describe '#post' do
     it 'should create a new object in persevere' do
       result = @p.create('/Class/', @blobObj)
       result.code.should == "201"
       JSON.parse(result.body).should == @mockObj
     end
     
     it 'should not allow posting with a bad object' do
       result = @p.create('/Class/', @corruptObj)
       result.code.should == "500"
       result.body.should == "\"Can not modify queries\""
     end
     
     it 'should not allow posting to an existing object/id/path' do
       result = @p.create('/Class/', @blobObj)
       result.code.should == "201"
       JSON.parse(result.body).should == @blobObj
       # This shouldn't be a 201, it should say something mean.
     end
   end
  
   #
   # Test GET to retrieve the list of classes from Persvr
   #
   describe '#get' do
     it 'should retrieve the previously created object from persevere' do
       result = @p.retrieve('/Class/Yogo')
       result.code.should == "200"
       JSON.parse(result.body).should == @blobObj
     end
     
     it 'should 404 on a non-existent object' do
       result = @p.retrieve('/Class/GetNotThere')
       result.code.should == "404"
       result.message.should == "Not Found"
     end
   end
  
   #
   # Test PUT to modify an existing class
   #
   describe '#put' do
     it 'should modify the previously created object in persevere' do
       @blobObj['properties']['tstAttribute'] = { 'type' => 'string' }
       result = @p.update('/Class/Yogo', @blobObj)
       result.code.should == "200"
       JSON.parse(result.body).should == @blobObj
     end
     
     it 'should fail to modify a non-existent item' do
       result = @p.update('/Class/NonExistent', @blobObj)
       result.code.should == "500"
       result.body.should == "\"id does not match location\""
       @p.delete('/Class/NonExistent') # A bug(?) in Persevere makes a broken NonExistent class.
       # This should be a 404 and not throw a persevere server exception
     end
   end
  
   #
   # Test DELETE to remove the previously created and modified class
   #
   describe '#delete' do
     it 'should remove the previously created and modified object from persevere' do
       result = @p.delete('/Class/Yogo')
       result.code.should == "204"
       @p.retrieve('/Class/Yogo').code.should == "404"
     end
     
     it 'should fail to delete a non-existent item' do
       result = @p.delete('/Class/NotThere')
       result.code.should == "404"
       result.message.should == "Not Found"
       result.body.should == "\"Class/NotThere not found\""
     end
   end
   
   describe "POSTing objects" do
     before(:all) do
       @p.create('/Class/', @blobObj)
     end
     
     it "should not allow nil fields to be posted" do
       obj_with_nil = @object.merge({'cid' => nil})
       result = @p.create('/Yogo', obj_with_nil)
       result.code.should == "201"
       JSON.parse(result.body).reject{|key,value| key == 'id' }.should == 
          obj_with_nil.reject{|key,value| value.nil?}
     end
     
     after(:all) do
       @p.delete('/Class/Yogo')
     end
   end
  
  describe "GETting limits and offsets" do
    before(:all) do
      @p.create('/Class/', @blobObj)
      (0..99).each do |i|
        @p.create('/Yogo/', @object.merge({'cid' => "#{i}"}))
      end
    end

    it "should only retrieve all objects" do
      result = @p.retrieve('/Yogo/')
      result.code.should == "200"
      JSON.parse(result.body).length.should == 100
    end
    
    it "should retrieve the first objects" do
      result = @p.retrieve('/Yogo/1')
      result.code.should == "200"
      JSON.parse(result.body)['id'].should == '1'
    end
    
    it "should retrieve a 10 of the objects" do
        result = @p.retrieve('/Yogo/', {'Range' => "items=1-10"})
        result.code.should == '206'
        JSON.parse(result.body).length.should == 10
    end
    
    it "should return the first 2 objects" do
      result = @p.retrieve('/Yogo/', {'Range' => "items=0-1"})
      result.code.should == '206'
      json = JSON.parse(result.body)
      json.length.should == 2
      json[0]['id'].should == '1'
      json[1]['id'].should == '2'
    end
    
    it "should return 21 and up objects" do
      result = @p.retrieve('/Yogo/', {'Range' => 'items=20-'})
      result.code.should == '206'
      json = JSON.parse(result.body)
      json.length.should == 80
      json[0]['id'].should == '21'
      json[-1]['id'].should == '100'      
    end

    it "should return objects with id's 11 - 15" do
      result = @p.retrieve('/Yogo/', {'Range' => 'items=10-14'})
      result.code.should == '206'
      json = JSON.parse(result.body)
      json.length.should == 5
      json[0]['id'].should == '11'
      json[-1]['id'].should == '15'      
    end
    
    after(:all) do
      @p.delete('/Class/Yogo')
    end
  end
end