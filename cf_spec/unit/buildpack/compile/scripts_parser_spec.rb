# Encoding: utf-8
# ASP.NET Core Buildpack
# Copyright 2016 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$LOAD_PATH << 'cf_spec'
require 'spec_helper'
require 'rspec'
require 'tmpdir'
require 'fileutils'

describe AspNetCoreBuildpack::ScriptsParser do
  let(:out)              { double(:out) }
  let(:dir)              { Dir.mktmpdir }
  let(:deps_dir)              { Dir.mktmpdir }
  let(:deps_idx)              { '77' }
  let(:sdk_msbuild)      { 'override' }
  let(:sdk_project_json) { 'override' }
  subject(:parser)       { described_class.new(dir, deps_dir, deps_idx) }

  before do
    allow(subject).to receive(:msbuild?).and_return(sdk_msbuild)
    allow(subject).to receive(:project_json?).and_return(sdk_project_json)
  end

  after do
    FileUtils.rm_rf(dir)
    FileUtils.rm_rf(deps_dir)
  end

  describe '#get_scripts_section' do

    context 'scripts section exists in project.json' do
      before do
        FileUtils.mkdir_p(File.join(dir, 'src', 'project1'))
        File.open(File.join(dir, 'src', 'project1', 'project.json'), 'w') { |f| f.write('{"scripts": { "precompile":["npm install", "bower install"] }}') }
      end

      it 'returns a json object representing the scripts section' do
        scripts_section = { 'precompile' => ['npm install', 'bower install'] }
        expect(subject.get_scripts_section(File.join(dir, 'src', 'project1', 'project.json'))).to eq(scripts_section)
      end
    end
  end

  describe '#key_contains_command' do
    let(:scripts_array) { { 'precompile' => ['another command', 'npm install'] } }
    let(:scripts_string) { { 'precompile' => 'npm install' } }

    context 'scripts section contains a key which has an array of commands' do
      it 'does not call key_string_contains_command' do
        expect(subject).not_to receive(:key_string_contains_command)
        subject.key_contains_command(scripts_array, 'precompile', 'npm')
      end

      it 'does call key_array_contains_command' do
        expect(subject).to receive(:key_array_contains_command)
        subject.key_contains_command(scripts_array, 'precompile', 'npm')
      end
    end

    context 'scripts section contains a key which is not an array' do
      it 'does call key_string_contains_command' do
        expect(subject).to receive(:key_string_contains_command)
        subject.key_contains_command(scripts_string, 'precompile', 'npm')
      end

      it 'does not call key_array_contains_command' do
        expect(subject).not_to receive(:key_array_contains_command)
        subject.key_contains_command(scripts_string, 'precompile', 'npm')
      end
    end
  end

  describe '#key_array_contains_command' do
    let(:scripts_array_with_two_commands) { { 'precompile' => ['another command && npm install'] } }
    let(:scripts_array_with_two_commands2) { { 'precompile' => ['npm install && another command'] } }
    let(:scripts_array_with_other_commands) { { 'precompile' => ['other command && another command'] } }
    let(:scripts_array) { { 'precompile' => ['another command', 'npm install'] } }
    let(:scripts_array_with_other_command) { { 'precompile' => ['other command'] } }

    context 'key contains two commands in the same string' do
      context 'one of the commands begins with the check_command' do
        it 'returns true' do
          expect(subject.key_array_contains_command(scripts_array_with_two_commands, 'precompile', 'npm')).to be_truthy
          expect(subject.key_array_contains_command(scripts_array_with_two_commands2, 'precompile', 'npm')).to be_truthy
        end
      end

      context 'none of the commands begin with the check_command' do
        it 'returns false' do
          expect(subject.key_array_contains_command(scripts_array_with_other_commands, 'precompile', 'npm')).not_to be_truthy
        end
      end
    end

    context 'key contains only one command in each string' do
      context 'one of the commands begins with the check_key' do
        it 'returns true' do
          expect(subject.key_array_contains_command(scripts_array, 'precompile', 'npm')).to be_truthy
        end
      end

      context 'none of the commands begin with the check_key' do
        it 'returns false' do
          expect(subject.key_array_contains_command(scripts_array_with_other_command, 'precompile', 'npm')).not_to be_truthy
        end
      end
    end
  end

  describe '#key_string_contains_command' do
    let(:scripts_with_two_commands) { { 'precompile' => 'another command && npm install' } }
    let(:scripts_with_two_commands2) { { 'precompile' => 'npm install && another command' } }
    let(:scripts_with_other_commands) { { 'precompile' => 'other command && another command' } }
    let(:scripts) { { 'precompile' => 'npm install' } }
    let(:scripts_with_other_command) { { 'precompile' => 'other command' } }

    context 'key contains two commands in the same string' do
      context 'one of the commands begins with the check_command' do
        it 'returns true' do
          expect(subject.key_string_contains_command(scripts_with_two_commands, 'precompile', 'npm')).to be_truthy
          expect(subject.key_string_contains_command(scripts_with_two_commands2, 'precompile', 'npm')).to be_truthy
        end
      end

      context 'none of the commands begin with the check_command' do
        it 'returns false' do
          expect(subject.key_string_contains_command(scripts_with_other_commands, 'precompile', 'npm')).not_to be_truthy
        end
      end
    end

    context 'key contains only one command in each string' do
      context 'the command begins with the check_key' do
        it 'returns true' do
          expect(subject.key_string_contains_command(scripts, 'precompile', 'npm')).to be_truthy
        end
      end

      context 'the command does not begin with the check_key' do
        it 'returns false' do
          expect(subject.key_string_contains_command(scripts_with_other_command, 'precompile', 'npm')).not_to be_truthy
        end
      end
    end
  end

  describe '#scripts_section_exists?' do
    before do
      FileUtils.mkdir_p(File.join(dir, 'src', 'project1'))
    end

    context 'sdk uses msbuild' do
      let(:sdk_msbuild)      { true }
      let(:sdk_project_json) { false }

      it 'use the xml parsing logic' do
        expect(subject).to receive(:xml_scripts_section_exists?).with(%w(command))
        subject.scripts_section_exists?(%w(command))
      end
    end

    context 'sdk uses project.json' do
      let(:sdk_msbuild)      { false }
      let(:sdk_project_json) { true }

      it 'use the json parsing logic' do
        expect(subject).to receive(:json_scripts_section_exists?).with(%w(command))
        subject.scripts_section_exists?(%w(command))
      end
    end

    context 'multiple project.json files exist' do
      let(:sdk_msbuild)      { false }
      let(:sdk_project_json) { true }

      before do
        FileUtils.mkdir_p(File.join(dir, 'src', 'project2'))
        File.open(File.join(dir, 'src', 'project1', 'project.json'), 'w') { |f| f.write('{"scripts": { "precompile":["other command", "another command"] }}') }
        File.open(File.join(dir, 'src', 'project2', 'project.json'), 'w') { |f| f.write('{"scripts": { "precompile":["npm install", "bower install"] }}') }
      end

      it 'calls get_scripts_section on each file' do
        expect(subject).to receive(:get_scripts_section).with(File.join(dir, 'src', 'project1', 'project.json'))
        expect(subject).to receive(:get_scripts_section).with(File.join(dir, 'src', 'project2', 'project.json'))
        subject.scripts_section_exists?(%w(npm))
      end

      it 'returns true if any of the files have a scripts section which contains the proper commands' do
        expect(subject.scripts_section_exists?(%w(npm))).to be_truthy
      end

      it 'calls key_contains_command on each scripts object' do
        expect(subject).to receive(:key_contains_command).with({ 'precompile' => ['other command', 'another command'] }, 'precompile', 'npm')
        expect(subject).to receive(:key_contains_command).with({ 'precompile' => ['npm install', 'bower install'] }, 'precompile', 'npm')
        subject.scripts_section_exists?(%w(npm))
      end
    end
  end

  describe '#xml_scripts_section_exists?' do
    let(:sample_xml) { 'override' }

    before do
      file_dir = FileUtils.mkdir_p(File.join(dir, 'xmldir'))
      File.write(File.join(file_dir, 'xml.csproj'), sample_xml)
    end

    context 'a valid AfterTargets attribute exists' do
      let(:sample_xml) do
        <<-XML
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\\Microsoft.Common.props" />

  <Target Name="SomeTarget" AfterTargets="Build" Condition=" '$(IsCrossTargetingBuild)' != 'true' ">
    <Exec Command="npm install" />
  </Target>

  <Import Project="$(MSBuildToolsPath)\\Microsoft.CSharp.targets" />
</Project>
XML
      end

      it 'returns true when the command is present' do
        expect(subject.xml_scripts_section_exists?(%w(npm))).to eq(true)
      end

      it 'returns false when the command is not present' do
        expect(subject.xml_scripts_section_exists?(%w(bash))).to eq(false)
      end


    end

    context 'the Target Name is BeforePublish' do
      let(:sample_xml) do
        <<-XML
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\\Microsoft.Common.props" />

  <Target Name="BeforePublish" Condition=" '$(IsCrossTargetingBuild)' != 'true' ">
    <Exec Command="npm install" />
  </Target>

  <Import Project="$(MSBuildToolsPath)\\Microsoft.CSharp.targets" />
</Project>
XML
      end

      it 'returns true when the command is present' do
        expect(subject.xml_scripts_section_exists?(%w(npm))).to eq(true)
      end

      it 'returns false when the command is not present' do
        expect(subject.xml_scripts_section_exists?(%w(bash))).to eq(false)
      end

    end

    context 'no valid Targets' do
      let(:sample_xml) do
        <<-XML
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\\Microsoft.Common.props" />

  <Target Name="SomeOtherScript" AfterTargets="SomeOtherTarget" Condition=" '$(IsCrossTargetingBuild)' != 'true' ">
    <Exec Command="npm install" />
  </Target>

  <Import Project="$(MSBuildToolsPath)\\Microsoft.CSharp.targets" />
</Project>
XML
      end

      it 'returns false no matter the command' do
        expect(subject.xml_scripts_section_exists?(%w(npm))).to eq(false)
        expect(subject.xml_scripts_section_exists?(%w(bash))).to eq(false)
      end
    end
  end
end
