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
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
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
        'cid' => {'type' => 'string' },
        'parent' => { 'type' => 'string'},
        'data' => { 'type' => 'string'}
      },
      'prototype' => {}
    }
  end
  
  #
  # Test POST to create a new class
  #
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
      result = @p.retrieve('/Class/NotThere')
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
      result = @p.update('/Class/NotThere', @blobObj)
      result.code.should == "500"
      result.body.should == "\"id does not match location\""
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
      result.code.should == "204"
      result.message.should == "No Content"
      result.body.should be_nil
      # This should be a 404 and not fail silently with a 204
    end
  end
end