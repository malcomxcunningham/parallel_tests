require 'spec_helper'

describe ParallelTests::RSpec::RuntimeLogger do
  before do
    # pretend we run in parallel or the logger will log nothing
    ENV['TEST_ENV_NUMBER'] = ''
    @clean_output = %r{^spec/foo.rb:[-\.e\d]+$}m
  end

  after do
    ENV.delete 'TEST_ENV_NUMBER'
  end

  def log_for_a_file(options={})
    Tempfile.open('xxx') do |temp|
      temp.close
      f = File.open(temp.path,'w')
      logger = if block_given?
        yield(f)
      else
        ParallelTests::RSpec::RuntimeLogger.new(f)
      end

      example = (mock(:location => "#{Dir.pwd}/spec/foo.rb:123"))
      logger.example_started example
      logger.example_passed example
      if options[:pending]
        logger.example_pending example
        logger.dump_pending
      end
      if options[:failed]
        logger.example_failed example
        logger.dump_failures
      end
      logger.start_dump

      #f.close
      return File.read(f.path)
    end
  end

  it "logs runtime with relative paths" do
    log_for_a_file.should =~ @clean_output
  end

  it "does not log pending" do
    log_for_a_file(:pending => true).should =~ @clean_output
  end

  it "does not log failures" do
    log_for_a_file(:failed => true).should =~ @clean_output
  end

  it "does not log if we do not run in parallel" do
    ENV.delete 'TEST_ENV_NUMBER'
    log_for_a_file.should == ""
  end

  it "appends to a given file" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelTests::RSpec::RuntimeLogger.new(f)
    end
    result.should include('FooBar')
    result.should include('foo.rb')
  end

  it "overwrites a given path" do
    result = log_for_a_file do |f|
      f.write 'FooBar'
      ParallelTests::RSpec::RuntimeLogger.new(f.path)
    end
    result.should_not include('FooBar')
    result.should include('foo.rb')
  end

  context "integration" do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir, &example)
      end
    end

    def write(file, content)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') { |f| f.write content }
    end

    it "logs shared examples into the running files" do
      pending "no support in rspec for this :/"

      write "spec/spec_helper.rb", <<-RUBY
        shared_examples "foo" do
          it "is slow" do
            sleep 0.5
          end
        end
      RUBY

      ["a", "b"].each do |letter|
        write "spec/#{letter}_spec.rb", <<-RUBY
          require 'spec_helper'
          describe 'xxx' do
            it_behaves_like "foo"
          end
        RUBY
      end

      system("TEST_ENV_NUMBER=1 rspec spec -I #{Bundler.root.join("lib")} --format ParallelTests::RSpec::RuntimeLogger --out runtime.log 2>&1") || raise("nope")

      result = File.read("runtime.log")
      result.should include "a_spec:0.5"
      result.should include "b_spec:0.5"
      result.should_not include "spec_helper"
    end
  end
end
