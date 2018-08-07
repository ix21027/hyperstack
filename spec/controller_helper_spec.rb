require 'spec_helper'

require 'rails-controller-testing'
Rails::Controller::Testing.install

# Rails 5.2.0 migration of the sqlite boolean
Rails.application.config.active_record.sqlite3.represent_boolean_as_integer = true

class TestController < ActionController::Base; end

RSpec.describe TestController, type: :controller do
  render_views

  describe '#render_component' do
    controller do

      layout "test_layout"

      def index
        render_component
      end

      def new
        render_component "Index", {}, layout: :explicit_layout
      end
    end

    it 'renders with the default layout' do
      get :index
      expect(response).to render_template(layout: :test_layout)
    end

    it "renders with a specified layout" do
      get :new
      expect(response).to render_template(layout: :explicit_layout)
    end
  end
end
