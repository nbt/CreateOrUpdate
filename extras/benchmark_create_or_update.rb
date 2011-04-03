# == SYNOPSIS:
#   % rails console
#   >> load 'extras/benchmark_create_or_update.rb'
#   >> BenchmarkCreateOrUpdate.benchmark(:key1, 2000, 2000, 2000)
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


  def self.benchmark(keys, n_common, n_disjoint, n_new, if_exists = :ignore)
    begin
      self.up
      candidates = setup(n_common, n_disjoint, n_new)
      Benchmark.bm(24) do |x|
        x.report("ActiveRecord") { TestRecord.create_or_update(candidates, keys, :if_exists => if_exists, :db_adaptor => "ActiveRecord") }
        x.report(ActiveRecord::Base.connection.adapter_name) { TestRecord.create_or_update(candidates, keys, :if_exists => if_exists) }
      end
    ensure
      self.down
    end
  end

end
