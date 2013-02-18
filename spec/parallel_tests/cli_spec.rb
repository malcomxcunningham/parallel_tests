require 'spec_helper'
require 'parallel_tests/cli'

describe ParallelTest::Cli do
  describe ".parse_options" do
    let(:defaults){ {:files => []} }

    def call(*args)
      subject.send(:parse_options!, *args)
    end

    it "parses regular count" do
      call(["-n3"]).should == defaults.merge(:count => 3)
    end

    it "parses count 0 as non-parallel" do
      call(["-n0"]).should == defaults.merge(:non_parallel => true)
    end

    it "parses non-parallel as non-parallel" do
      call(["--non-parallel"]).should == defaults.merge(:non_parallel => true)
    end
  end

  describe ".final_fail_message" do
    it 'returns a plain fail message if colors are nor supported' do
      subject.should_receive(:use_colors?).and_return(false)
      subject.send(:final_fail_message, "Test").should ==  "Tests Failed"
    end

    it 'returns a colorized fail message if colors are supported' do
      subject.should_receive(:use_colors?).and_return(true)
      subject.send(:final_fail_message, "Test").should == "\e[31mTests Failed\e[0m"
    end
  end
end
