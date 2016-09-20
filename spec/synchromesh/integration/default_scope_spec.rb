require 'spec_helper'
require 'synchromesh/integration/test_components'

describe "default_scope" do

  context "client tests", js: true do

    before(:all) do
      require 'pusher'
      require 'pusher-fake'
      Pusher.app_id = "MY_TEST_ID"
      Pusher.key =    "MY_TEST_KEY"
      Pusher.secret = "MY_TEST_SECRET"
      require "pusher-fake/support/base"

      Synchromesh.configuration do |config|
        config.transport = :pusher
        config.channel_prefix = "synchromesh"
        config.opts = {app_id: Pusher.app_id, key: Pusher.key, secret: Pusher.secret}.merge(PusherFake.configuration.web_options)
      end
    end

    before(:each) do
      # spec_helper resets the policy system after each test so we have to setup
      # before each test
      stub_const 'TestApplication', Class.new
      stub_const 'TestApplicationPolicy', Class.new
      TestApplicationPolicy.class_eval do
        always_allow_connection
        regulate_all_broadcasts { |policy| policy.send_all }
        allow_change(to: :all, on: [:create, :update, :destroy]) { true }
      end
      size_window(:small, :portrait)
      isomorphic do
        TestModel.class_eval do
          default_scope { where(completed: true) }
          default_scope { where(test_attribute: 'foo') }
        end
      end
    end

    after(:each) do
      TestModel.default_scopes = []
    end

    it "the count of the default_scope will be sent with the updates" do
      mount "TestComponent2" do
        class TestComponent2 < React::Component::Base
          render(:div) do
            "#{TestModel.count} items".br
            "#{TestModel.unscoped.count} unscoped items"
          end
        end
      end
      page.should have_content("0 items")
      page.should have_content("0 unscoped items")
      m1 = FactoryGirl.create(:test_model, completed: false, test_attribute: nil)
      page.should have_content("0 items")
      page.should have_content("1 unscoped items")
      wait_for_ajax
      last_fetch_at = evaluate_ruby("ReactiveRecord::Base.last_fetch_at.to_f")
      m2 = FactoryGirl.create(:test_model, completed: true, test_attribute: nil)
      page.should have_content("0 items")
      page.should have_content("2 unscoped items")
      m2.update(test_attribute: 'foo')
      page.should have_content("1 items")
      page.should have_content("2 unscoped items")
      m3 = FactoryGirl.create(:test_model)
      page.should have_content("2 items")
      page.should have_content("3 unscoped items")
      m3.update_attribute(:completed, false)
      page.should have_content("1 items")
      page.should have_content("3 unscoped items")
      m2.destroy
      page.should have_content("0 items")
      page.should have_content("2 unscoped items")
      evaluate_ruby("ReactiveRecord::Base.last_fetch_at.to_f").should eq(last_fetch_at)
    end

    it "the models existence in the default_scope will be sent with the updates" do
      mount "TestComponent2" do
        class TestComponent2 < React::Component::Base
          render(:div) do
            "#{TestModel.all.all.count} items".br
            "#{TestModel.unscoped.all.count} unscoped items"
          end
        end
      end
      page.should have_content("0 items")
      page.should have_content("0 unscoped items")
      m1 = FactoryGirl.create(:test_model, completed: false, test_attribute: nil)
      page.should have_content("0 items")
      page.should have_content("1 unscoped items")
      wait_for_ajax
      last_fetch_at = evaluate_ruby("ReactiveRecord::Base.last_fetch_at.to_f")
      m2 = FactoryGirl.create(:test_model, completed: true, test_attribute: nil)
      page.should have_content("0 items")
      page.should have_content("2 unscoped items")
      m2.update(test_attribute: 'foo')
      page.should have_content("1 items")
      page.should have_content("2 unscoped items")
      m3 = FactoryGirl.create(:test_model)
      page.should have_content("2 items")
      page.should have_content("3 unscoped items")
      m3.update_attribute(:completed, false)
      page.should have_content("1 items")
      page.should have_content("3 unscoped items")
      m2.destroy
      page.should have_content("0 items")
      page.should have_content("2 unscoped items")
      evaluate_ruby("ReactiveRecord::Base.last_fetch_at.to_f").should eq(last_fetch_at)
    end
  end

  context "server side" do
    it "will not calculate default scope information if no default scopes are defined" do
      stub_const 'TestApplication', Class.new
      stub_const 'TestApplicationPolicy', Class.new
      TestApplicationPolicy.class_eval do
        always_allow_connection
        regulate_all_broadcasts { |policy| policy.send_only(:id, :test_attribute) }
      end
      allow_any_instance_of(Synchromesh::InternalPolicy).to receive(:id).and_return(:unique_broadcast_id)
      allow(Synchromesh::Connection).to receive(:active).and_return(['TestApplication'])
      model = FactoryGirl.create(:test_model)
      expect { |b| Synchromesh::InternalPolicy.regulate_broadcast(model, &b) }.to yield_successive_args(
        {
          broadcast_id: :unique_broadcast_id,
          channel: 'TestApplication',
          channels: ['TestApplication'],
          klass: 'TestModel',
          record: {id: model.id, test_attribute: nil},
          previous_changes: {:id=>[nil, 1]}
        }
      )
    end
  end
end
