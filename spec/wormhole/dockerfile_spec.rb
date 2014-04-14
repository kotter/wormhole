# encoding: utf-8
require 'spec_helper'
require 'pp'

describe 'jumanjiman/wormhole' do
  before :all do
    @docker_version = Docker.version['Version']
    if @docker_version >= '0.9'
      key, repo = 'RepoTags', 'jumanjiman/wormhole:latest'
      @image = Docker::Image.all.find { |i| i.info[key].include?(repo) }
    else
      key, repo = 'Repository', 'jumanjiman/wormhole'
      @image = Docker::Image.all.find { |i| i.info[key] == repo }
    end
    pp Docker::Image.all unless @image
  end

  describe 'image' do
    it 'should be available' do
      @image.should_not be_nil
    end
  end

  describe 'docker' do
    before :each do
      @config = @image.json['config']
    end

    it 'should expose ssh port and only ssh port' do
      @config['ExposedPorts'].keys.should =~ ['22/tcp']
    end

    it 'should run sshd with logging' do
      @config['Cmd'].include?('/usr/sbin/sshd -D -e').should be_true
    end

    volumes = %W(
      /home/user
      /media/state/etc/ssh
    )

    volumes.each do |vol|
      it "should have volume #{vol}" do
        @config['Volumes'].keys.include?(vol).should be_true
      end
    end
  end

  describe 'packages' do
    prohibited_packages = %W(
      sudo
    )

    prohibited_packages.each do |package|
      it "should not have #{package} installed" do
        dr = 'docker run --rm -i -t jumanjiman/wormhole'
        output = %x(#{dr} rpm -q #{package} 2> /dev/null).split($RS)
        output[0].chomp.should =~ /^package #{package} is not installed$/
      end
    end
  end

  describe 'user convenience' do
    it 'man -k returns results' do
      dr = 'docker run --rm -i -t jumanjiman/wormhole man -k git 2> /dev/null'
      output = %x(#{dr} 2> /dev/null).split($RS)
      output.length.should >= 10
    end

    # @note This rspec also asserts that /etc/issue.net is available for sshd.
    it 'locate returns the path for issue.net' do
      dr = 'docker run --rm -i -t jumanjiman/wormhole locate issue.net'
      output = %x(#{dr} 2> /dev/null).split($RS)
      output[0].chomp.should =~ %r{/etc/issue.net}
    end
  end
end
