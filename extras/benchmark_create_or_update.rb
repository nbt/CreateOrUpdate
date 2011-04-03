# == SYNOPSIS:
#   % rails console
#   >> load 'extras/benchmark_create_or_update.rb'
#   >> BenchmarkCreateOrUpdate.benchmark(:key1, 2000, 2000, 2000, :ignore)
#   >> BenchmarkCreateOrUpdate.benchmark(:key1, 2000, 2000, 2000, :update)
#
module BenchmarkCreateOrUpdate

  require 'create_or_update'

  class TestRecord < ActiveRecord::Base
    include CreateOrUpdate
  end

  def self.up
    ActiveRecord::Schema.define do
      create_table(:test_records, :force => true) do |t|
        t.integer :key1
        t.integer :key2
        t.float   :value
      end
    end
  end

  def self.down
    ActiveRecord::Schema.define do
      drop_table(:test_records)
    end
  end

  # Create (n_common + n_disjoint) records in the database, return a
  # list of (n_common + n_new) test records, not (yet) in the database
  #
  def self.setup(n_common, n_disjoint, n_new)
    TestRecord.delete_all
    (n_common + n_disjoint).times do |i|
      TestRecord.create(:key1 => i+1, :key2 => i, :value => (i+1).to_f)
    end
    candidates = []
    incumbents = TestRecord.all
    n_common.times do |i|
      candidate = TestRecord.new
      candidate.attributes = incumbents[i].attributes
      candidates << candidate
    end
    n_new.times do |i|
      candidates << TestRecord.new(:key1 => -i, :key2 => i, :value => -i.to_f)
    end
    candidates
  end

  def self.bench(label, width)
    TestRecord.transaction do
      tms = Benchmark.measure(label) { yield }
      print(tms.label.ljust(width) + tms.to_s)
      raise ActiveRecord::Rollback
    end
  end
    
  def self.benchmark(keys = :key1, n_common = 2000, n_disjoint = 2000, n_new = 2000)
    begin
      self.up
      candidates = setup(n_common, n_disjoint, n_new)
      width = 20
      print("".ljust(width) + Benchmark::Tms::CAPTION)
      2.times do
        bench(ActiveRecord::Base.connection.adapter_name + " :ignore", width) {
          TestRecord.create_or_update(candidates, keys, :if_exists => :ignore)
        }
        bench("ActiveRecord :ignore", width) { 
          TestRecord.create_or_update(candidates, keys, :if_exists => :ignore, :db_adaptor => "ActiveRecord") 
        }
      end
      2.times do
        bench(ActiveRecord::Base.connection.adapter_name + " :update", width) {
          TestRecord.create_or_update(candidates, keys, :if_exists => :update)
        }
        bench("ActiveRecord :update", width) { 
          TestRecord.create_or_update(candidates, keys, :if_exists => :update, :db_adaptor => "ActiveRecord") 
        }
      end
    ensure
      self.down
    end
  end

end
