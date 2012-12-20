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
      Pants::Logger.log = false

      x.report("\tpants:") do
        tee = Pants.new(file_path) do |tee|
          options[:times].times do |i|
            tee.add_writer("pants_test#{i}")
          end
        end

        tee.run
      end

      x.report(" FileUtils.cp:") do
        options[:times].times do |i|
          FileUtils.cp('pants_test1', "cp_test#{i}")
        end
      end
    end
  rescue
    FileUtils.rm(Dir["./pants_test*"])
    FileUtils.rm(Dir["./cp_test*"])

    raise
  ensure
    FileUtils.rm(Dir["./pants_test*"])
    FileUtils.rm(Dir["./cp_test*"])
  end
end

Pantsmark.start
