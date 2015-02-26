require "spec_helper"
require "parallel_tests/cli"
require "parallel_tests/rspec/runner"

describe ParallelTests::CLI do
  subject { ParallelTests::CLI.new }

  describe "#parse_options" do
    let(:defaults){ {:files => ["test"]} }

    def call(*args)
      subject.send(:parse_options!, *args)
    end

    it "fails without file" do
      subject.should_receive(:abort).with("Pass files or folders to run")
      call(["-n3"])
    end

    it "parses execute" do
      call(["--exec", "echo"]).should == {execute: "echo", files: []}
    end

    it "parses regular count" do
      call(["test", "-n3"]).should == defaults.merge(:count => 3)
    end

    it "parses count 0 as non-parallel" do
      call(["test", "-n0"]).should == defaults.merge(:non_parallel => true)
    end

    it "parses non-parallel as non-parallel" do
      call(["test", "--non-parallel"]).should == defaults.merge(:non_parallel => true)
    end

    it "finds the correct type when multiple are given" do
      call(["test", "--type", "test", "-t", "rspec"])
      subject.instance_variable_get(:@runner).should == ParallelTests::RSpec::Runner
    end

    it "parses nice as nice" do
      call(["test", "--nice"]).should == defaults.merge(:nice => true)
    end

    it "parses --verbose" do
      call(["test", "--verbose"]).should == defaults.merge(:verbose => true)
    end

    context "parse only-group" do
      it "group_by should be set to filesize" do
        call(["test", "--only-group", '1']).should == defaults.merge(only_group: [1], group_by: :filesize)
      end

      it "allows runtime" do
        call(["test", "--only-group", '1', '--group-by', 'runtime']).should == defaults.merge(only_group: [1], group_by: :runtime)
      end

      it "raise error when group_by isn't filesize" do
        expect{
          call(["test", "--only-group", '1', '--group-by', 'steps'])
        }.to raise_error(RuntimeError)
      end

      it "with multiple groups" do
        call(["test", "--only-group", '4,5']).should == defaults.merge(only_group: [4,5], group_by: :filesize)
      end

      it "with a single group" do
        call(["test", "--only-group", '4']).should == defaults.merge(:only_group => [4], group_by: :filesize)
      end
    end
  end

  describe "#load_runner" do
    it "requires and loads default runner" do
      subject.should_receive(:require).with("parallel_tests/test/runner")
      subject.send(:load_runner, "test").should == ParallelTests::Test::Runner
    end

    it "requires and loads rspec runner" do
      subject.should_receive(:require).with("parallel_tests/rspec/runner")
      subject.send(:load_runner, "rspec").should == ParallelTests::RSpec::Runner
    end

    it "requires and loads runner with underscores" do
      subject.should_receive(:require).with("parallel_tests/my_test_runner/runner")
      subject.send(:load_runner, "my_test_runner").should == ParallelTests::MyTestRunner::Runner
    end

    it "fails to load unfindable runner" do
      expect{
        subject.send(:load_runner, "foo").should == ParallelTests::RSpec::Runner
      }.to raise_error(LoadError)
    end
  end

  describe "#final_fail_message" do
    before do
      subject.instance_variable_set(:@runner, ParallelTests::Test::Runner)
    end

    it 'returns a plain fail message if colors are nor supported' do
      subject.should_receive(:use_colors?).and_return(false)
      subject.send(:final_fail_message).should ==  "Tests Failed"
    end

    it 'returns a colorized fail message if colors are supported' do
      subject.should_receive(:use_colors?).and_return(true)
      subject.send(:final_fail_message).should == "\e[31mTests Failed\e[0m"
    end
  end

  describe "#run_tests_in_parallel" do
    context "specific groups to run" do
      let(:results){ {:stdout => "", :exit_status => 0} }
      before do
        subject.stub(:puts)
        subject.should_receive(:load_runner).with("my_test_runner").and_return(ParallelTests::MyTestRunner::Runner)
        ParallelTests::MyTestRunner::Runner.stub(:test_file_name).and_return("test")
        ParallelTests::MyTestRunner::Runner.should_receive(:tests_in_groups).and_return([
          ['aaa','bbb'],
          ['ccc', 'ddd'],
          ['eee', 'fff']
        ])
        subject.should_receive(:report_results).and_return(nil)
      end

      it "calls run_tests once when one group specified" do
        subject.should_receive(:run_tests).once.and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '1', '-t', 'my_test_runner'])
      end

      it "calls run_tests twice when two groups are specified" do
        subject.should_receive(:run_tests).twice.and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '1,2', '-t', 'my_test_runner'])
      end

      it "run only one group specified" do
        options = {count: 3, only_group: [2], files: ["test"], group_by: :filesize}
        subject.should_receive(:run_tests).once.with(['ccc', 'ddd'], 0, 1, options).and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '2', '-t', 'my_test_runner'])
      end

      it "run twice with multiple groups" do
        options = {count: 3, only_group: [2,3], files: ["test"], group_by: :filesize}
        subject.should_receive(:run_tests).once.ordered.with(['ccc', 'ddd'], 0, 1, options).and_return(results)
        subject.should_receive(:run_tests).once.ordered.with(['eee', 'fff'], 1, 1, options).and_return(results)
        subject.run(['test', '-n', '3', '--only-group', '2,3', '-t', 'my_test_runner'])
      end
    end
  end

  describe "#display_duration" do
    def call(*args)
      subject.send(:detailed_duration, *args)
    end

    it "displays for durations near one minute" do
      call(59).should == nil
      call(60).should == " (1:00)"
      call(61).should == " (1:01)"
    end

    it "displays for durations near one hour" do
      call(3599).should == " (59:59)"
      call(3600).should == " (1:00:00)"
      call(3601).should == " (1:00:01)"
    end

    it "displays the correct string for miscellaneous durations" do
      call(9296).should  == " (2:34:56)"
      call(45296).should == " (12:34:56)"
      call(2756601).should == " (765:43:21)" # hours into three digits?  Buy more CI hardware...
      call(0).should == nil
    end
  end
end

module ParallelTests
  module MyTestRunner
    class Runner
    end
  end
end
