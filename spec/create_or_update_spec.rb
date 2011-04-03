require 'spec_helper'
require 'create_or_update'

describe CreateOrUpdate do

  # ================================================================
  # Create a TestRecord model for these tests
  class TestRecord < ActiveRecord::Base
    include CreateOrUpdate
  end

  before(:all) do
    ActiveRecord::Schema.define do
      create_table :test_records, :force => true do |t|
        t.integer  :f_integer
        t.string   :f_string
        t.float    :f_float
        t.decimal  :f_decimal, :precision => 9, :scale => 6
        t.datetime :f_datetime
        t.timestamps
      end
    end
  end

  after(:all) do
    ActiveRecord::Schema.define do
      drop_table :test_records
    end
  end

  ALL_KEYS = [:f_integer, :f_string, :f_float, :f_decimal, :f_datetime]
  NO_KEYS = []

  # ================================================================
  # verify the db table equals the array of records (except for id, created_at, updated_at)

  def verify_table_length(records)
    records.size == TestRecord.count
  end

  def verify_table_contents(records)
    t = records.all? do |r|
      conditions = ALL_KEYS.inject({}) {|h,k| h[k] = r.send(k); h}
      TestRecord.find(:first, :conditions => conditions)
    end
  end

  # debugging aid
  def report(records)
    $stderr.puts("==== expected")
    records.each {|r| $stderr.puts("    #{r.inspect}")}
    $stderr.puts("==== found")
    TestRecord.all.each {|r| $stderr.puts("    #{r.inspect}")}
  end

  # ================================================================
  before(:each) do
    @datetime_001 = DateTime.parse("2001-01-01")
    @datetime_002 = DateTime.parse("2002-01-01")
    @datetime_100 = DateTime.parse("2100-01-01")
  end
  
  # ================================================================
  describe "with empty table" do
    before(:each) do
      @candidates = 
        [
         @candidate001 = TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
         @candidate100 = TestRecord.new(:f_integer => 100, :f_string => "100", :f_float => 100.0, :f_decimal => 100, :f_datetime => @datetime_100),
        ]
    end
    
    it "should start with zero incumbents" do
      TestRecord.count.should == 0
    end
    
    it "should call create_or_update on an empty list without error" do
      lambda { TestRecord.create_or_update([], NO_KEYS) }.should_not raise_error
    end
    
    it "should accept a singleton key in lieu of a list" do
      lambda { TestRecord.create_or_update(@candidates, ALL_KEYS.first, :if_exists => :ignore) }.should_not raise_error
      TestRecord.count.should == @candidates.size
    end

    describe "under :ignore" do

      it "should create the right contents when all keys are specified" do
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :ignore)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

      ALL_KEYS.each do |key|
        it "should create the right contents when #{key} is specified" do
          TestRecord.create_or_update(@candidates, [key], :if_exists => :ignore)
          TestRecord.count.should == @candidates.size
          verify_table_contents(@candidates).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :ignore)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

    end                         # describe "under :ignore" do

    describe "under :update" do

      it "should create the right contents when all keys are specified" do
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :update)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

      ALL_KEYS.each do |key|
        it "should create the right contents when #{key} is specified" do
          TestRecord.create_or_update(@candidates, [key], :if_exists => :update)
          TestRecord.count.should == @candidates.size
          verify_table_contents(@candidates).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :update)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

    end                         # describe "under :update" do

    describe "under :error" do

      it "should create the right contents when all keys are specified" do
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :error)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

      ALL_KEYS.each do |key|
        it "should create the right contents when #{key} is specified" do
          TestRecord.create_or_update(@candidates, [key], :if_exists => :error)
          TestRecord.count.should == @candidates.size
          verify_table_contents(@candidates).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :error)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

    end                         # describe "under :error" do

  end                           # describe "with empty table" do

  # ================================================================
  describe "with one identical entry in table" do
    before(:each) do
      @incumbents = 
        [
         @incumbent001 = TestRecord.create(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
        ]
      @candidates = 
        [
         @candidate001 = TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
         @candidate100 = TestRecord.new(:f_integer => 100, :f_string => "100", :f_float => 100.0, :f_decimal => 100, :f_datetime => @datetime_100),
        ]
    end
    
    it "should start with zero incumbents" do
      TestRecord.count.should == 1
    end
    
    describe "under :ignore" do

      it "should create the right contents when all keys are specified" do
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :ignore)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

      ALL_KEYS.each do |key|
        it "should create the right contents when #{key} is specified" do
          TestRecord.create_or_update(@candidates, [key], :if_exists => :ignore)
          TestRecord.count.should == @candidates.size
          verify_table_contents(@candidates).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :ignore)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :ignore" do

    describe "under :update" do

      it "should create the right contents when all keys are specified" do
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :update)
        TestRecord.count.should == @candidates.size
        verify_table_contents(@candidates).should == true
      end

      ALL_KEYS.each do |key|
        it "should create the right contents when #{key} is specified" do
          TestRecord.create_or_update(@candidates, [key], :if_exists => :update)
          TestRecord.count.should == @candidates.size
          verify_table_contents(@candidates).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :update" do

    describe "under :error" do

      it "should raise error when all keys are specified" do
        lambda do
          TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :error)
        end.should raise_error(CreateOrUpdate::RecordNotUnique)
        TestRecord.count.should == 1
      end

      ALL_KEYS.each do |key|
        it "should raise error when #{key} is specified" do
          lambda do
            TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :error)
          end.should raise_error(CreateOrUpdate::RecordNotUnique)
          TestRecord.count.should == 1
        end
      end

      it "should not raise error when no keys are specified" do
        expected = @incumbents + @candidates
        lambda do
          TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :error)
        end.should_not raise_error
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :error" do

  end                           # describe "with one entry in table" do

  # ================================================================
  describe "with multiple entries in table" do
    before(:each) do
      @incumbents = 
        [
         @incumbent001 = TestRecord.create(:f_integer => 1, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
         @incumbent002 = TestRecord.create(:f_integer => 2, :f_string => "1", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
         @incumbent003 = TestRecord.create(:f_integer => 2, :f_string => "2", :f_float => 1.0, :f_decimal => 2, :f_datetime => @datetime_002),
         @incumbent004 = TestRecord.create(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 1, :f_datetime => @datetime_002),
         @incumbent005 = TestRecord.create(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_001),
         @incumbent006 = TestRecord.create(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
        ]
      @candidates = 
        [
         @candidate001 = TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
        ]
    end
    
    it "should start with correct number of incumbents" do
      TestRecord.count.should == @incumbents.size
    end
    
    describe "under :ignore" do

      it "should create the right contents when all keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :ignore)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      ALL_KEYS.each do |key|
        it "should not touch the contents when #{key} is specified" do
          expected = @incumbents
          TestRecord.create_or_update(@candidates, :f_integer, :if_exists => :ignore)
          TestRecord.count.should == expected.size
          verify_table_contents(expected).should == true
        end
      end

      it "should create the right contents when no keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :ignore)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :ignore" do

    describe "under :update" do

      it "should create the right contents when all keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when :f_integer is specified" do
        expected = 
          [
           TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "1", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 1.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 1, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
          ]
        TestRecord.create_or_update(@candidates, :f_integer, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when :f_string is specified" do
        expected = 
          [
           TestRecord.new(:f_integer => 1, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 1.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 1, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
          ]
        TestRecord.create_or_update(@candidates, :f_string, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when :f_float is specified" do
        expected = 
          [
           TestRecord.new(:f_integer => 1, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "1", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 1, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
          ]
        TestRecord.create_or_update(@candidates, :f_float, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when :f_decimal is specified" do
        expected = 
          [
           TestRecord.new(:f_integer => 1, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "1", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 1.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
          ]
        TestRecord.create_or_update(@candidates, :f_decimal, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when :f_datetime is specified" do
        expected = 
          [
           TestRecord.new(:f_integer => 1, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "1", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 1.0, :f_decimal => 2, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 1, :f_datetime => @datetime_002),
           TestRecord.new(:f_integer => 1, :f_string => "1", :f_float => 1.0, :f_decimal => 1, :f_datetime => @datetime_001),
           TestRecord.new(:f_integer => 2, :f_string => "2", :f_float => 2.0, :f_decimal => 2, :f_datetime => @datetime_002),
          ]
        TestRecord.create_or_update(@candidates, :f_datetime, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      it "should create the right contents when no keys are specified" do
        expected = @incumbents + @candidates
        TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :update)
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :update" do

    describe "under :error" do

      it "should raise error when all keys are specified" do
        expected = @incumbents + @candidates
        lambda do
          TestRecord.create_or_update(@candidates, ALL_KEYS, :if_exists => :error)
        end.should_not raise_error
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

      ALL_KEYS.each do |key|
        it "should raise error when #{key} is specified" do
          lambda do
            TestRecord.create_or_update(@candidates, key, :if_exists => :error)
          end.should raise_error(CreateOrUpdate::RecordNotUnique)
          TestRecord.count.should == @incumbents.size
        end
      end

      it "should not raise error when no keys are specified" do
        expected = @incumbents + @candidates
        lambda do
          TestRecord.create_or_update(@candidates, NO_KEYS, :if_exists => :error)
        end.should_not raise_error
        TestRecord.count.should == expected.size
        verify_table_contents(expected).should == true
      end

    end                         # describe "under :error" do

  end                          # describe "with one identical and one different entry in table" do

  # ================================================================
  describe "testing timestamps" do

    it "should set created_at if not previously set" do
      candidate = TestRecord.new(:f_integer => 9999, :created_at => nil)
      TestRecord.create_or_update([candidate], ALL_KEYS, :if_exists => :ignore)
      TestRecord.find(:first, :conditions => {:f_integer => 9999}).created_at.should_not == nil
    end
    
    it "should not modify created_at if previously set" do
      t = Time.zone.parse("2010-01-01")
      candidate = TestRecord.new(:f_integer => 9999, :created_at => t)
      TestRecord.create_or_update([candidate], ALL_KEYS, :if_exists => :ignore)
      TestRecord.find(:first, :conditions => {:f_integer => 9999}).created_at.should == t
    end
    
    it "should update updated_at if not previously set" do
      candidate = TestRecord.new(:f_integer => 9999, :updated_at => nil)
      TestRecord.create_or_update([candidate], ALL_KEYS, :if_exists => :ignore)
      TestRecord.find(:first, :conditions => {:f_integer => 9999}).updated_at.should_not == nil
    end
    
  end                           # describe "testing created_at and updated_at" do
  
end                             # describe CreateOrUpdate do
