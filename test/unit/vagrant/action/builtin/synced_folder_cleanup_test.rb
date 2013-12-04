require "pathname"
require "tmpdir"

require File.expand_path("../../../../base", __FILE__)

describe Vagrant::Action::Builtin::SyncedFolderCleanup do
  include_context "synced folder actions"

  let(:app) { lambda { |env| } }
  let(:env) { { :machine => machine, :ui => ui } }
  let(:machine) do
    double("machine").tap do |machine|
      machine.stub(:config).and_return(machine_config)
    end
  end

  let(:machine_config) do
    double("machine_config").tap do |top_config|
      top_config.stub(:vm => vm_config)
    end
  end

  let(:vm_config) { double("machine_vm_config") }

  let(:ui) do
    double("ui").tap do |result|
      result.stub(:info)
    end
  end

  subject { described_class.new(app, env) }

  def create_cleanup_tracker
    Class.new(impl(true, "good")) do
      class_variable_set(:@@clean, false)

      def self.clean
        class_variable_get(:@@clean)
      end

      def cleanup(machine)
        self.class.class_variable_set(:@@clean, true)
      end
    end
  end

  describe "call" do
    let(:synced_folders) { {} }
    let(:plugins) { {} }

    before do
      plugins[:default] = [impl(true, "default"), 10]
      plugins[:nfs] = [impl(true, "nfs"), 5]

      env[:root_path] = Pathname.new(Dir.mktmpdir)

      subject.stub(:plugins => plugins)
      subject.stub(:synced_folders => synced_folders)
    end

    it "should invoke cleanup" do
      tracker = create_cleanup_tracker
      plugins[:tracker] = [tracker, 15]

      synced_folders["tracker"] = {
        "root" => {
          hostpath: "foo",
        },

        "other" => {
          hostpath: "bar",
          create: true,
        }
      }

      subject.call(env)
      tracker.clean.should be_true
    end

    it "should invoke cleanup once per implementation" do
      trackers = []
      (0..2).each do |tracker|
        trackers << create_cleanup_tracker
      end

      plugins[:tracker_0] = [trackers[0], 15]
      plugins[:tracker_1] = [trackers[1], 15]
      plugins[:tracker_2] = [trackers[2], 15]

      synced_folders["tracker_0"] = {
        "root" => {
          hostpath: "foo"
        },

        "other" => {
          hostpath: "bar",
          create: true
        }
      }

      synced_folders["tracker_1"] = {
        "root" => {
          hostpath: "foo"
        }
      }

      synced_folders["tracker_2"] = {
        "root" => {
          hostpath: "foo"
        },

        "other" => {
          hostpath: "bar",
          create: true
        },

        "another" => {
          hostpath: "baz"
        }
      }

      subject.call(env)

      trackers[0].clean.should be_true
      trackers[1].clean.should be_true
      trackers[2].clean.should be_true
    end
  end
end
