#!/usr/bin/env ruby

require 'thor'
require 'benchmark'
require './lib/pants'
require 'bundler/setup'


class Pantsmark < Thor
  desc "file_copy [FILE]", "Copies [FILE] --times number of times and benchmarks it"
  method_option :times, type: :numeric, :default => 100
  def file_copy(file_path)
    Benchmark.bm do |x|
      Pants.log = false

      x.report("\tpants:") do
        Pants.read(file_path) do |tee|
          options[:times].times do |i|
            tee.add_writer("pants_test#{i}")
          end
        end
      end

      options[:times].times do |i|
        result = %x[diff "#{file_path}" pants_test#{i}]
        puts "Diff result: #{result}" unless result.empty?
      end

      x.report(" FileUtils.cp:") do
        threads = []

        options[:times].times do |i|
          threads << Thread.new do
            FileUtils.cp('pants_test1', "fu_cp_test#{i}")
          end

          threads.last.join
        end
      end

      x.report("           cp:") do
        threads = []

        options[:times].times do |i|
          threads << Thread.new do
            `cp pants_test1 cp_test#{i}`
          end

          threads.last.join
        end
      end
    end
  rescue
    FileUtils.rm_rf(Dir["./pants_test*"])
    FileUtils.rm_rf(Dir["./fu_cp_test*"])
    FileUtils.rm_rf(Dir["./cp_test*"])

    raise
  ensure
    FileUtils.rm_rf(Dir["./pants_test*"])
    FileUtils.rm_rf(Dir["./fu_cp_test*"])
    FileUtils.rm_rf(Dir["./cp_test*"])
  end
end

Pantsmark.start
